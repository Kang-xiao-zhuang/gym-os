package com.zk.gymos.service;

import com.zk.gymos.common.BusinessException;
import com.zk.gymos.common.ResultCode;
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
                saved.size(), volume(saved), distinctExercises(saved));
    }

    @Transactional(readOnly = true)
    public List<SessionResponse> list(UUID userId) {
        return sessionRepo.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(s -> {
                    List<WorkoutLog> logs = logRepo.findBySessionId(s.getId());
                    return SessionResponse.of(s, dayTitle(s.getWorkoutDayId()),
                            logs.size(), volume(logs), distinctExercises(logs));
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
