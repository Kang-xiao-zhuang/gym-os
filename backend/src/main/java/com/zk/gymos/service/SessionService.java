package com.zk.gymos.service;

import com.zk.gymos.common.BusinessException;
import com.zk.gymos.common.ResultCode;
import com.zk.gymos.dto.ExerciseTrendResponse;
import com.zk.gymos.dto.InsightsResponse;
import com.zk.gymos.dto.LastPerformanceResponse;
import com.zk.gymos.dto.PrResponse;
import com.zk.gymos.dto.SessionDetailResponse;
import com.zk.gymos.dto.SessionRequest;
import com.zk.gymos.dto.SessionResponse;
import com.zk.gymos.entity.Exercise;
import com.zk.gymos.entity.WorkoutDay;
import com.zk.gymos.entity.WorkoutLog;
import com.zk.gymos.entity.WorkoutSession;
import com.zk.gymos.repository.ExerciseRepository;
import com.zk.gymos.repository.WorkoutDayRepository;
import com.zk.gymos.repository.WorkoutLogRepository;
import com.zk.gymos.repository.WorkoutSessionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.function.Function;
import java.util.stream.Collectors;

/** Training history: sessions + per-set logs, scoped to the user. */
@Service
public class SessionService {

    private final WorkoutSessionRepository sessionRepo;
    private final WorkoutLogRepository logRepo;
    private final WorkoutDayRepository dayRepo;
    private final ExerciseRepository exerciseRepo;

    public SessionService(WorkoutSessionRepository sessionRepo, WorkoutLogRepository logRepo,
                          WorkoutDayRepository dayRepo, ExerciseRepository exerciseRepo) {
        this.sessionRepo = sessionRepo;
        this.logRepo = logRepo;
        this.dayRepo = dayRepo;
        this.exerciseRepo = exerciseRepo;
    }

    @Transactional
    public SessionResponse create(UUID userId, SessionRequest req) {
        WorkoutSession s = new WorkoutSession();
        s.setUserId(userId);
        s.setWorkoutDayId(req.workoutDayId());
        s.setStartedAt(req.startedAt());
        s.setFinishedAt(OffsetDateTime.now());
        s.setDurationMinutes(req.durationMinutes());
        sessionRepo.save(s);

        List<SessionRequest.LogEntry> entries = req.logs() == null ? List.of() : req.logs();
        List<WorkoutLog> saved = new ArrayList<>();
        for (SessionRequest.LogEntry e : entries) {
            WorkoutLog log = new WorkoutLog();
            log.setSessionId(s.getId());
            log.setExerciseId(e.exerciseId());
            log.setSetNo(e.setNo());
            log.setWeight(e.weight());
            log.setReps(e.reps());
            log.setIsCompleted(true);
            saved.add(logRepo.save(log));
        }
        return SessionResponse.of(s, dayTitle(req.workoutDayId()),
                saved.size(), volume(saved), distinctExercises(saved), 0);
    }

    @Transactional(readOnly = true)
    public List<SessionResponse> list(UUID userId) {
        List<WorkoutSession> sessions = sessionRepo.findByUserIdOrderByCreatedAtDesc(userId);
        if (sessions.isEmpty()) return List.of();

        // Load logs once per session, and equipment for every referenced exercise.
        Map<UUID, List<WorkoutLog>> logsBySession = new HashMap<>();
        Set<UUID> exIds = new HashSet<>();
        for (WorkoutSession s : sessions) {
            List<WorkoutLog> logs = logRepo.findBySessionId(s.getId());
            logsBySession.put(s.getId(), logs);
            for (WorkoutLog l : logs) exIds.add(l.getExerciseId());
        }
        Map<UUID, String> equipById = exerciseRepo.findAllById(exIds).stream()
                .collect(Collectors.toMap(Exercise::getId, e -> e.getEquipment() == null ? "" : e.getEquipment()));

        // Walk oldest→newest, tracking running records per exercise. A session earns a PR
        // for an exercise when it BEATS an existing record (weight for weighted moves, total
        // session reps for bodyweight) — first-ever occurrences don't count (nothing to beat).
        Map<UUID, BigDecimal> maxWeight = new HashMap<>();
        Map<UUID, Integer> maxSessionReps = new HashMap<>();
        Map<UUID, Integer> prCountBySession = new HashMap<>();
        List<WorkoutSession> chrono = new ArrayList<>(sessions);
        Collections.reverse(chrono);
        for (WorkoutSession s : chrono) {
            Map<UUID, BigDecimal> sMaxW = new HashMap<>();
            Map<UUID, Integer> sSumReps = new HashMap<>();
            for (WorkoutLog l : logsBySession.get(s.getId())) {
                if (l.getReps() != null) sSumReps.merge(l.getExerciseId(), l.getReps(), Integer::sum);
                if (l.getWeight() != null) sMaxW.merge(l.getExerciseId(), l.getWeight(),
                        (a, b) -> b.compareTo(a) > 0 ? b : a);
            }
            Set<UUID> exInSession = new HashSet<>();
            exInSession.addAll(sMaxW.keySet());
            exInSession.addAll(sSumReps.keySet());
            int cnt = 0;
            for (UUID ex : exInSession) {
                if ("自重".equals(equipById.get(ex))) {
                    Integer sr = sSumReps.get(ex);
                    if (sr == null) continue;
                    Integer prev = maxSessionReps.get(ex);
                    if (prev != null && sr > prev) cnt++;
                    if (prev == null || sr > prev) maxSessionReps.put(ex, sr);
                } else {
                    BigDecimal sw = sMaxW.get(ex);
                    if (sw == null) continue;
                    BigDecimal prev = maxWeight.get(ex);
                    if (prev != null && sw.compareTo(prev) > 0) cnt++;
                    if (prev == null || sw.compareTo(prev) > 0) maxWeight.put(ex, sw);
                }
            }
            prCountBySession.put(s.getId(), cnt);
        }

        return sessions.stream()
                .map(s -> {
                    List<WorkoutLog> logs = logsBySession.get(s.getId());
                    return SessionResponse.of(s, dayTitle(s.getWorkoutDayId()),
                            logs.size(), volume(logs), distinctExercises(logs),
                            prCountBySession.getOrDefault(s.getId(), 0));
                })
                .toList();
    }

    @Transactional(readOnly = true)
    public SessionDetailResponse detail(UUID userId, UUID sessionId) {
        WorkoutSession s = require(userId, sessionId);
        List<WorkoutLog> logs = logRepo.findBySessionId(sessionId);
        Map<UUID, Exercise> byId = exerciseRepo
                .findAllById(logs.stream().map(WorkoutLog::getExerciseId).distinct().toList()).stream()
                .collect(Collectors.toMap(Exercise::getId, Function.identity()));

        // Group logs by exercise, preserving first-seen order, sets sorted by setNo.
        LinkedHashMap<UUID, List<WorkoutLog>> grouped = new LinkedHashMap<>();
        for (WorkoutLog l : logs) {
            grouped.computeIfAbsent(l.getExerciseId(), k -> new ArrayList<>()).add(l);
        }
        List<SessionDetailResponse.ExerciseLog> exercises = grouped.entrySet().stream().map(en -> {
            Exercise e = byId.get(en.getKey());
            List<SessionDetailResponse.SetLog> sets = en.getValue().stream()
                    .sorted(Comparator.comparing(l -> l.getSetNo() == null ? 0 : l.getSetNo()))
                    .map(l -> new SessionDetailResponse.SetLog(l.getSetNo(), l.getWeight(), l.getReps()))
                    .toList();
            return new SessionDetailResponse.ExerciseLog(
                    en.getKey(),
                    e == null ? "(已删除动作)" : e.getName(),
                    e == null ? null : e.getBodyPart(),
                    sets);
        }).toList();

        return new SessionDetailResponse(s.getId(), dayTitle(s.getWorkoutDayId()),
                s.getStartedAt(), s.getFinishedAt(), s.getDurationMinutes(),
                logs.size(), volume(logs), exercises);
    }

    /** Latest logged performance of an exercise (null if never done). */
    @Transactional(readOnly = true)
    public LastPerformanceResponse lastPerformance(UUID userId, UUID exerciseId) {
        List<WorkoutLog> logs = logRepo.findByUserAndExerciseNewestFirst(userId, exerciseId);
        if (logs.isEmpty()) return null;
        UUID latestSession = logs.getFirst().getSessionId();
        List<LastPerformanceResponse.SetLog> sets = logs.stream()
                .filter(l -> latestSession.equals(l.getSessionId()))
                .sorted(Comparator.comparing(l -> l.getSetNo() == null ? 0 : l.getSetNo()))
                .map(l -> new LastPerformanceResponse.SetLog(l.getSetNo(), l.getWeight(), l.getReps()))
                .toList();
        return new LastPerformanceResponse(logs.getFirst().getCreatedAt(), sets);
    }

    /**
     * Personal record for an exercise. Null only if the exercise has never been logged at all.
     * Weighted moves report maxWeight/bestSetVolume; bodyweight moves report {@code bestReps} =
     * the most TOTAL reps done for this exercise in a single training session (sum across its
     * sets), so progress is measured by session volume, not a single-set max.
     */
    @Transactional(readOnly = true)
    public PrResponse personalRecord(UUID userId, UUID exerciseId) {
        List<WorkoutLog> logs = logRepo.findByUserAndExerciseNewestFirst(userId, exerciseId);
        WorkoutLog maxW = null;      // heaviest weight (single set)
        WorkoutLog bestVol = null;   // best single-set volume (weight×reps)
        Map<UUID, Integer> repsPerSession = new LinkedHashMap<>();  // sessionId → total reps of this exercise
        for (WorkoutLog l : logs) {
            if (l.getReps() != null) {
                repsPerSession.merge(l.getSessionId(), l.getReps(), Integer::sum);
            }
            if (l.getWeight() == null) continue;
            if (maxW == null || l.getWeight().compareTo(maxW.getWeight()) > 0) maxW = l;
            if (l.getReps() != null) {
                BigDecimal vol = l.getWeight().multiply(BigDecimal.valueOf(l.getReps()));
                BigDecimal bestVolVal = (bestVol == null || bestVol.getReps() == null) ? null
                        : bestVol.getWeight().multiply(BigDecimal.valueOf(bestVol.getReps()));
                if (bestVol == null || bestVolVal == null || vol.compareTo(bestVolVal) > 0) bestVol = l;
            }
        }
        Integer bestReps = null;         // most total reps in one session
        UUID bestRepsSession = null;
        for (Map.Entry<UUID, Integer> en : repsPerSession.entrySet()) {
            if (bestReps == null || en.getValue() > bestReps) {
                bestReps = en.getValue();
                bestRepsSession = en.getKey();
            }
        }
        if (maxW == null && bestReps == null) return null;

        OffsetDateTime achievedAt = maxW != null ? maxW.getCreatedAt() : null;
        if (achievedAt == null && bestRepsSession != null) {
            for (WorkoutLog l : logs) {
                if (bestRepsSession.equals(l.getSessionId()) && l.getCreatedAt() != null
                        && (achievedAt == null || l.getCreatedAt().isBefore(achievedAt))) {
                    achievedAt = l.getCreatedAt();
                }
            }
        }
        return new PrResponse(
                maxW == null ? null : maxW.getWeight(),
                maxW == null ? null : maxW.getReps(),
                bestVol == null ? null : bestVol.getWeight().multiply(BigDecimal.valueOf(bestVol.getReps())),
                bestReps,
                achievedAt);
    }

    /** Per-session trend of one exercise (oldest→newest): max weight + volume each session. */
    @Transactional(readOnly = true)
    public ExerciseTrendResponse trend(UUID userId, UUID exerciseId) {
        List<WorkoutLog> logs = logRepo.findByUserAndExerciseNewestFirst(userId, exerciseId);
        // Group by session, keep each session's date (min createdAt), max weight, total volume.
        LinkedHashMap<UUID, List<WorkoutLog>> bySession = new LinkedHashMap<>();
        for (WorkoutLog l : logs) {
            bySession.computeIfAbsent(l.getSessionId(), k -> new ArrayList<>()).add(l);
        }
        List<ExerciseTrendResponse.Point> points = new ArrayList<>();
        for (List<WorkoutLog> group : bySession.values()) {
            BigDecimal maxW = null;
            BigDecimal vol = BigDecimal.ZERO;
            OffsetDateTime date = null;
            for (WorkoutLog l : group) {
                if (date == null || (l.getCreatedAt() != null && l.getCreatedAt().isBefore(date))) date = l.getCreatedAt();
                if (l.getWeight() != null) {
                    if (maxW == null || l.getWeight().compareTo(maxW) > 0) maxW = l.getWeight();
                    if (l.getReps() != null) vol = vol.add(l.getWeight().multiply(BigDecimal.valueOf(l.getReps())));
                }
            }
            points.add(new ExerciseTrendResponse.Point(date, maxW, vol));
        }
        // findByUser... is newest-first; reverse to oldest→newest for charting.
        java.util.Collections.reverse(points);
        return new ExerciseTrendResponse(points);
    }

    /** Coaching insights: this-month body-part balance, plateaus, biggest recent gain. */
    @Transactional(readOnly = true)
    public InsightsResponse insights(UUID userId) {
        List<WorkoutSession> sessions = sessionRepo.findByUserIdOrderByCreatedAtDesc(userId);
        if (sessions.isEmpty()) return new InsightsResponse(List.of(), List.of(), null);

        Map<UUID, List<WorkoutLog>> logsBySession = new HashMap<>();
        Set<UUID> exIds = new HashSet<>();
        for (WorkoutSession s : sessions) {
            List<WorkoutLog> ls = logRepo.findBySessionId(s.getId());
            logsBySession.put(s.getId(), ls);
            for (WorkoutLog l : ls) exIds.add(l.getExerciseId());
        }
        Map<UUID, Exercise> exById = exerciseRepo.findAllById(exIds).stream()
                .collect(Collectors.toMap(Exercise::getId, Function.identity()));

        // Per-exercise chronological points (oldest→newest).
        record ExPoint(OffsetDateTime date, BigDecimal maxW, int sets) {}
        List<WorkoutSession> chrono = new ArrayList<>(sessions);
        java.util.Collections.reverse(chrono);
        OffsetDateTime now = OffsetDateTime.now();

        Map<UUID, List<ExPoint>> byEx = new LinkedHashMap<>();
        Map<String, Integer> partSetsThisMonth = new LinkedHashMap<>();
        for (WorkoutSession s : chrono) {
            OffsetDateTime date = s.getCreatedAt();
            Map<UUID, BigDecimal> sMaxW = new HashMap<>();
            Map<UUID, Integer> sSets = new HashMap<>();
            for (WorkoutLog l : logsBySession.get(s.getId())) {
                sSets.merge(l.getExerciseId(), 1, Integer::sum);
                if (l.getWeight() != null) {
                    sMaxW.merge(l.getExerciseId(), l.getWeight(), (a, b) -> b.compareTo(a) > 0 ? b : a);
                }
            }
            boolean thisMonth = date != null && date.getYear() == now.getYear() && date.getMonthValue() == now.getMonthValue();
            for (UUID ex : sSets.keySet()) {
                byEx.computeIfAbsent(ex, k -> new ArrayList<>())
                        .add(new ExPoint(date, sMaxW.get(ex), sSets.get(ex)));
                if (thisMonth) {
                    Exercise e = exById.get(ex);
                    String bp = (e == null || e.getBodyPart() == null) ? "其他" : e.getBodyPart();
                    partSetsThisMonth.merge(bp, sSets.get(ex), Integer::sum);
                }
            }
        }

        List<InsightsResponse.BodyPartLoad> bodyParts = partSetsThisMonth.entrySet().stream()
                .sorted((a, b) -> b.getValue() - a.getValue())
                .map(en -> new InsightsResponse.BodyPartLoad(en.getKey(), en.getValue()))
                .toList();

        // Plateaus: weighted exercises whose top weight didn't improve across the last ≤4 sessions.
        List<InsightsResponse.Plateau> plateaus = new ArrayList<>();
        OffsetDateTime cutoff = now.minusDays(30);
        InsightsResponse.Gain bestGain = null;
        for (Map.Entry<UUID, List<ExPoint>> en : byEx.entrySet()) {
            Exercise e = exById.get(en.getKey());
            if (e == null || "自重".equals(e.getEquipment())) continue;
            List<ExPoint> weighted = en.getValue().stream().filter(p -> p.maxW() != null).toList();

            if (weighted.size() >= 3) {
                List<ExPoint> window = weighted.subList(Math.max(0, weighted.size() - 4), weighted.size());
                if (window.get(window.size() - 1).maxW().compareTo(window.get(0).maxW()) <= 0) {
                    plateaus.add(new InsightsResponse.Plateau(e.getName(), window.get(window.size() - 1).maxW(), window.size()));
                }
            }

            List<ExPoint> recent = weighted.stream().filter(p -> p.date() != null && p.date().isAfter(cutoff)).toList();
            if (recent.size() >= 2) {
                BigDecimal from = recent.get(0).maxW();
                BigDecimal to = recent.get(recent.size() - 1).maxW();
                BigDecimal delta = to.subtract(from);
                if (delta.signum() > 0 && (bestGain == null || delta.compareTo(bestGain.delta()) > 0)) {
                    bestGain = new InsightsResponse.Gain(e.getName(), from, to, delta);
                }
            }
        }
        plateaus.sort((a, b) -> b.sessions() - a.sessions());
        if (plateaus.size() > 3) plateaus = plateaus.subList(0, 3);

        return new InsightsResponse(bodyParts, plateaus, bestGain);
    }

    @Transactional
    public void delete(UUID userId, UUID sessionId) {
        require(userId, sessionId);
        logRepo.deleteBySessionId(sessionId);
        sessionRepo.deleteById(sessionId);
    }

    private BigDecimal volume(List<WorkoutLog> logs) {
        BigDecimal sum = BigDecimal.ZERO;
        for (WorkoutLog l : logs) {
            if (l.getWeight() != null && l.getReps() != null) {
                sum = sum.add(l.getWeight().multiply(BigDecimal.valueOf(l.getReps())));
            }
        }
        return sum;
    }

    private long distinctExercises(List<WorkoutLog> logs) {
        return logs.stream().map(WorkoutLog::getExerciseId).distinct().count();
    }

    private WorkoutSession require(UUID userId, UUID sessionId) {
        WorkoutSession s = sessionRepo.findById(sessionId)
                .orElseThrow(() -> BusinessException.notFound("记录不存在"));
        if (!userId.equals(s.getUserId())) {
            throw new BusinessException(ResultCode.FORBIDDEN, "无权访问");
        }
        return s;
    }

    private String dayTitle(UUID dayId) {
        if (dayId == null) return null;
        return dayRepo.findById(dayId).map(WorkoutDay::getTitle).orElse(null);
    }
}
