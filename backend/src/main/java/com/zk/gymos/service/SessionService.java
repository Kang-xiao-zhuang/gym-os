package com.zk.gymos.service;

import com.zk.gymos.common.BusinessException;
import com.zk.gymos.common.ResultCode;
import com.zk.gymos.dto.CalendarDayResponse;
import com.zk.gymos.dto.ExerciseTrendResponse;
import com.zk.gymos.dto.ImportResult;
import com.zk.gymos.dto.ImportSessionsRequest;
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
import java.time.Instant;
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
        Map<UUID, List<WorkoutLog>> logsBySession = groupLogsBySession(sessions);
        Set<UUID> exIds = new HashSet<>();
        for (List<WorkoutLog> group : logsBySession.values()) {
            for (WorkoutLog l : group) exIds.add(l.getExerciseId());
        }
        Map<UUID, String> equipById = exerciseRepo.findAllById(exIds).stream()
                .collect(Collectors.toMap(Exercise::getId, e -> e.getEquipment() == null ? "" : e.getEquipment()));

        Map<UUID, Integer> prCountBySession = prCountsBySession(sessions, logsBySession, equipById);

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

        return buildDetail(s, logs, byId);
    }

    /** All the user's sessions with full per-set detail, in one efficient pass (for data export). */
    @Transactional(readOnly = true)
    public List<SessionDetailResponse> exportAll(UUID userId) {
        List<WorkoutSession> sessions = sessionRepo.findByUserIdOrderByCreatedAtDesc(userId);
        if (sessions.isEmpty()) return List.of();
        Map<UUID, List<WorkoutLog>> logsBySession = groupLogsBySession(sessions);
        Set<UUID> exIds = new HashSet<>();
        for (List<WorkoutLog> group : logsBySession.values()) {
            for (WorkoutLog l : group) exIds.add(l.getExerciseId());
        }
        Map<UUID, Exercise> byId = exerciseRepo.findAllById(exIds).stream()
                .collect(Collectors.toMap(Exercise::getId, Function.identity()));
        return sessions.stream()
                .map(s -> buildDetail(s, logsBySession.getOrDefault(s.getId(), List.of()), byId))
                .toList();
    }

    /** Build a SessionDetailResponse from a session + its logs (grouped by exercise, sets by setNo). */
    private SessionDetailResponse buildDetail(WorkoutSession s, List<WorkoutLog> logs, Map<UUID, Exercise> byId) {
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
            BigDecimal best1rm = null;
            OffsetDateTime date = null;
            for (WorkoutLog l : group) {
                if (date == null || (l.getCreatedAt() != null && l.getCreatedAt().isBefore(date))) date = l.getCreatedAt();
                if (l.getWeight() != null) {
                    if (maxW == null || l.getWeight().compareTo(maxW) > 0) maxW = l.getWeight();
                    if (l.getReps() != null) {
                        vol = vol.add(l.getWeight().multiply(BigDecimal.valueOf(l.getReps())));
                        // Epley estimated 1RM = w × (1 + reps/30)
                        BigDecimal e = l.getWeight().multiply(
                                BigDecimal.ONE.add(BigDecimal.valueOf(l.getReps())
                                        .divide(BigDecimal.valueOf(30), 4, java.math.RoundingMode.HALF_UP)));
                        if (best1rm == null || e.compareTo(best1rm) > 0) best1rm = e;
                    }
                }
            }
            if (best1rm != null) best1rm = best1rm.setScale(1, java.math.RoundingMode.HALF_UP);
            points.add(new ExerciseTrendResponse.Point(date, maxW, vol, best1rm));
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

        Map<UUID, List<WorkoutLog>> logsBySession = groupLogsBySession(sessions);
        Set<UUID> exIds = new HashSet<>();
        for (List<WorkoutLog> group : logsBySession.values()) {
            for (WorkoutLog l : group) exIds.add(l.getExerciseId());
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

    /**
     * Month calendar: for each day the user trained in {@code ym}, which body parts were hit
     * (ordered by sets desc, for the coloured dots), the day's total sets/volume/duration, and a
     * compact per-exercise breakdown for the day sheet. Days with no training are simply absent.
     */
    @Transactional(readOnly = true)
    public List<CalendarDayResponse> calendar(UUID userId, java.time.YearMonth ym) {
        List<WorkoutSession> all = sessionRepo.findByUserIdOrderByCreatedAtDesc(userId);
        List<WorkoutSession> inMonth = all.stream()
                .filter(s -> s.getCreatedAt() != null
                        && s.getCreatedAt().getYear() == ym.getYear()
                        && s.getCreatedAt().getMonthValue() == ym.getMonthValue())
                .toList();
        if (inMonth.isEmpty()) return List.of();

        // Load ALL logs (PR detection needs full history) + exercises.
        Map<UUID, List<WorkoutLog>> logsBySession = groupLogsBySession(all);
        Set<UUID> exIds = new HashSet<>();
        for (List<WorkoutLog> group : logsBySession.values()) {
            for (WorkoutLog l : group) exIds.add(l.getExerciseId());
        }
        Map<UUID, Exercise> exById = exerciseRepo.findAllById(exIds).stream()
                .collect(Collectors.toMap(Exercise::getId, Function.identity()));
        Map<UUID, String> equipById = new HashMap<>();
        exById.forEach((id, e) -> equipById.put(id, e.getEquipment() == null ? "" : e.getEquipment()));
        Map<UUID, Integer> prBySession = prCountsBySession(all, logsBySession, equipById);

        // Group the month's sessions by local date (a day may hold >1 session).
        Map<java.time.LocalDate, List<WorkoutSession>> byDate = new TreeMap<>();
        for (WorkoutSession s : inMonth) {
            byDate.computeIfAbsent(s.getCreatedAt().toLocalDate(), k -> new ArrayList<>()).add(s);
        }

        List<CalendarDayResponse> out = new ArrayList<>();
        for (Map.Entry<java.time.LocalDate, List<WorkoutSession>> en : byDate.entrySet()) {
            LinkedHashMap<UUID, int[]> setsReps = new LinkedHashMap<>(); // exerciseId -> [sets, totalReps]
            Map<UUID, BigDecimal> topW = new HashMap<>();
            Map<String, Integer> partSets = new LinkedHashMap<>();
            int totalSets = 0, prCount = 0;
            BigDecimal totalVol = BigDecimal.ZERO;
            Integer totalDur = null;
            for (WorkoutSession s : en.getValue()) {
                prCount += prBySession.getOrDefault(s.getId(), 0);
                if (s.getDurationMinutes() != null) totalDur = (totalDur == null ? 0 : totalDur) + s.getDurationMinutes();
                for (WorkoutLog l : logsBySession.getOrDefault(s.getId(), List.of())) {
                    UUID ex = l.getExerciseId();
                    int[] sr = setsReps.computeIfAbsent(ex, k -> new int[2]);
                    sr[0]++;
                    if (l.getReps() != null) sr[1] += l.getReps();
                    totalSets++;
                    if (l.getWeight() != null) {
                        topW.merge(ex, l.getWeight(), (a, b) -> b.compareTo(a) > 0 ? b : a);
                        if (l.getReps() != null) totalVol = totalVol.add(l.getWeight().multiply(BigDecimal.valueOf(l.getReps())));
                    }
                    Exercise e = exById.get(ex);
                    String bp = (e == null || e.getBodyPart() == null) ? "其他" : e.getBodyPart();
                    partSets.merge(bp, 1, Integer::sum);
                }
            }
            List<String> bodyParts = partSets.entrySet().stream()
                    .sorted((a, b) -> b.getValue() - a.getValue())
                    .map(Map.Entry::getKey).toList();
            List<CalendarDayResponse.ExerciseBrief> exercises = setsReps.entrySet().stream()
                    .sorted((a, b) -> b.getValue()[0] - a.getValue()[0])
                    .map(e2 -> {
                        Exercise e = exById.get(e2.getKey());
                        return new CalendarDayResponse.ExerciseBrief(
                                e2.getKey(),
                                e == null ? "(已删除动作)" : e.getName(),
                                (e == null || e.getBodyPart() == null) ? "其他" : e.getBodyPart(),
                                e2.getValue()[0], topW.get(e2.getKey()), e2.getValue()[1]);
                    }).toList();
            out.add(new CalendarDayResponse(en.getKey(), bodyParts, totalSets, totalVol,
                    totalDur, en.getValue().size(), prCount, exercises));
        }
        return out;
    }

    /**
     * Import sessions from a JSON backup. Idempotent by session finish-instant (duplicates skipped).
     * Exercises are matched by id then by name; unmatched names are auto-created (with body part).
     */
    @Transactional
    public ImportResult importSessions(UUID userId, List<ImportSessionsRequest.SessionImport> sessions) {
        if (sessions == null || sessions.isEmpty()) return new ImportResult(0, 0, 0);

        // Dedup key = existing sessions' finish instants for this user.
        Set<Instant> existing = sessionRepo.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(WorkoutSession::getFinishedAt).filter(Objects::nonNull)
                .map(OffsetDateTime::toInstant).collect(Collectors.toCollection(HashSet::new));

        // Exercise resolution caches (shared library).
        List<Exercise> all = exerciseRepo.findAll();
        Map<UUID, Exercise> byId = all.stream()
                .collect(Collectors.toMap(Exercise::getId, Function.identity(), (a, b) -> a));
        Map<String, Exercise> byName = new HashMap<>();
        for (Exercise e : all) byName.putIfAbsent(e.getName(), e);

        int imported = 0, skipped = 0, exCreated = 0;
        for (ImportSessionsRequest.SessionImport si : sessions) {
            Instant fin = si.finishedAt() == null ? null : si.finishedAt().toInstant();
            if (fin != null && existing.contains(fin)) { skipped++; continue; }

            WorkoutSession s = new WorkoutSession();
            s.setUserId(userId);
            s.setStartedAt(si.startedAt());
            s.setFinishedAt(si.finishedAt());
            s.setDurationMinutes(si.durationMinutes());
            sessionRepo.save(s);

            List<ImportSessionsRequest.ExerciseImport> exs = si.exercises() == null ? List.of() : si.exercises();
            for (ImportSessionsRequest.ExerciseImport ei : exs) {
                Exercise ex;
                if (ei.exerciseId() != null && byId.containsKey(ei.exerciseId())) {
                    ex = byId.get(ei.exerciseId());
                } else if (ei.name() != null && byName.containsKey(ei.name())) {
                    ex = byName.get(ei.name());
                } else {
                    ex = new Exercise();
                    ex.setName(ei.name() == null || ei.name().isBlank() ? "(导入动作)" : ei.name());
                    ex.setBodyPart(ei.bodyPart() == null || ei.bodyPart().isBlank() ? "其他" : ei.bodyPart());
                    ex.setDifficulty((short) 1);
                    exerciseRepo.save(ex);
                    byId.put(ex.getId(), ex);
                    byName.putIfAbsent(ex.getName(), ex);
                    exCreated++;
                }
                List<ImportSessionsRequest.SetImport> sets = ei.sets() == null ? List.of() : ei.sets();
                for (ImportSessionsRequest.SetImport st : sets) {
                    WorkoutLog log = new WorkoutLog();
                    log.setSessionId(s.getId());
                    log.setExerciseId(ex.getId());
                    log.setSetNo(st.setNo());
                    log.setWeight(st.weight());
                    log.setReps(st.reps());
                    log.setIsCompleted(true);
                    logRepo.save(log);
                }
            }
            if (fin != null) existing.add(fin);
            imported++;
        }
        return new ImportResult(imported, skipped, exCreated);
    }

    @Transactional
    public void delete(UUID userId, UUID sessionId) {
        require(userId, sessionId);
        logRepo.deleteBySessionId(sessionId);
        sessionRepo.deleteById(sessionId);
    }

    /**
     * PR count per session. Walks oldest→newest tracking running records per exercise; a session
     * earns a PR for an exercise when it BEATS an existing record (weight for weighted moves, total
     * session reps for bodyweight moves) — first-ever occurrences don't count (nothing to beat).
     * {@code sessionsDesc} is newest-first (as the repo returns).
     */
    private Map<UUID, Integer> prCountsBySession(List<WorkoutSession> sessionsDesc,
                                                 Map<UUID, List<WorkoutLog>> logsBySession,
                                                 Map<UUID, String> equipById) {
        Map<UUID, BigDecimal> maxWeight = new HashMap<>();
        Map<UUID, Integer> maxSessionReps = new HashMap<>();
        Map<UUID, Integer> prCountBySession = new HashMap<>();
        List<WorkoutSession> chrono = new ArrayList<>(sessionsDesc);
        Collections.reverse(chrono);
        for (WorkoutSession s : chrono) {
            Map<UUID, BigDecimal> sMaxW = new HashMap<>();
            Map<UUID, Integer> sSumReps = new HashMap<>();
            for (WorkoutLog l : logsBySession.getOrDefault(s.getId(), List.of())) {
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
        return prCountBySession;
    }

    /** All logs for the given sessions in ONE query, grouped by session id (empty list for logless sessions). */
    private Map<UUID, List<WorkoutLog>> groupLogsBySession(List<WorkoutSession> sessions) {
        List<UUID> ids = sessions.stream().map(WorkoutSession::getId).toList();
        Map<UUID, List<WorkoutLog>> map = new HashMap<>();
        for (UUID id : ids) map.put(id, new ArrayList<>());
        for (WorkoutLog l : logRepo.findBySessionIdIn(ids)) {
            map.computeIfAbsent(l.getSessionId(), k -> new ArrayList<>()).add(l);
        }
        return map;
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
