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

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/** Training history: sessions + per-exercise logs, scoped to the user. */
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

        List<UUID> ids = req.exerciseIds() == null ? List.of() : req.exerciseIds();
        for (UUID exId : ids) {
            WorkoutLog log = new WorkoutLog();
            log.setSessionId(s.getId());
            log.setExerciseId(exId);
            log.setIsCompleted(true);
            logRepo.save(log);
        }
        return SessionResponse.of(s, dayTitle(req.workoutDayId()), ids.size());
    }

    @Transactional(readOnly = true)
    public List<SessionResponse> list(UUID userId) {
        return sessionRepo.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(s -> SessionResponse.of(s, dayTitle(s.getWorkoutDayId()), logRepo.countBySessionId(s.getId())))
                .toList();
    }

    @Transactional(readOnly = true)
    public SessionDetailResponse detail(UUID userId, UUID sessionId) {
        WorkoutSession s = require(userId, sessionId);
        List<WorkoutLog> logs = logRepo.findBySessionId(sessionId);
        Map<UUID, Exercise> byId = exerciseRepo
                .findAllById(logs.stream().map(WorkoutLog::getExerciseId).toList()).stream()
                .collect(Collectors.toMap(Exercise::getId, Function.identity()));
        List<SessionDetailResponse.LoggedExercise> exercises = logs.stream()
                .map(l -> {
                    Exercise e = byId.get(l.getExerciseId());
                    return new SessionDetailResponse.LoggedExercise(
                            l.getExerciseId(),
                            e == null ? "(已删除动作)" : e.getName(),
                            e == null ? null : e.getBodyPart());
                })
                .toList();
        return new SessionDetailResponse(s.getId(), dayTitle(s.getWorkoutDayId()),
                s.getStartedAt(), s.getFinishedAt(), s.getDurationMinutes(), exercises);
    }

    @Transactional
    public void delete(UUID userId, UUID sessionId) {
        require(userId, sessionId);
        logRepo.deleteBySessionId(sessionId);
        sessionRepo.deleteById(sessionId);
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
