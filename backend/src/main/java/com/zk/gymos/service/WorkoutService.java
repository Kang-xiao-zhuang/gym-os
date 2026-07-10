package com.zk.gymos.service;

import com.zk.gymos.common.BusinessException;
import com.zk.gymos.common.ResultCode;
import com.zk.gymos.dto.*;
import com.zk.gymos.entity.Exercise;
import com.zk.gymos.entity.WorkoutDay;
import com.zk.gymos.entity.WorkoutDayExercise;
import com.zk.gymos.entity.WorkoutPlan;
import com.zk.gymos.repository.ExerciseRepository;
import com.zk.gymos.repository.WorkoutDayExerciseRepository;
import com.zk.gymos.repository.WorkoutDayRepository;
import com.zk.gymos.repository.WorkoutPlanRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;

/** Training plans → days → day-exercises. Everything is scoped to the calling user. */
@Service
public class WorkoutService {

    private final WorkoutPlanRepository planRepo;
    private final WorkoutDayRepository dayRepo;
    private final WorkoutDayExerciseRepository dayExerciseRepo;
    private final ExerciseRepository exerciseRepo;

    public WorkoutService(WorkoutPlanRepository planRepo, WorkoutDayRepository dayRepo,
                          WorkoutDayExerciseRepository dayExerciseRepo, ExerciseRepository exerciseRepo) {
        this.planRepo = planRepo;
        this.dayRepo = dayRepo;
        this.dayExerciseRepo = dayExerciseRepo;
        this.exerciseRepo = exerciseRepo;
    }

    // ---------- plans ----------

    @Transactional(readOnly = true)
    public List<PlanResponse> listPlans(UUID userId) {
        return planRepo.findByUserIdOrderByCreatedAtDesc(userId).stream().map(PlanResponse::of).toList();
    }

    @Transactional
    public PlanResponse createPlan(UUID userId, PlanRequest req) {
        WorkoutPlan p = new WorkoutPlan();
        p.setUserId(userId);
        p.setName(req.name());
        p.setDescription(req.description());
        p.setIcon(req.icon());
        if (req.totalWeeks() != null) {
            p.setTotalWeeks(req.totalWeeks());
        }
        if (req.isActive() != null) {
            p.setIsActive(req.isActive());
        }
        return PlanResponse.of(planRepo.save(p));
    }

    @Transactional
    public PlanResponse updatePlan(UUID userId, UUID planId, PlanRequest req) {
        WorkoutPlan p = requirePlan(userId, planId);
        p.setName(req.name());
        p.setDescription(req.description());
        if (req.icon() != null) {
            p.setIcon(req.icon());
        }
        if (req.totalWeeks() != null) {
            p.setTotalWeeks(req.totalWeeks());
        }
        if (req.isActive() != null) {
            p.setIsActive(req.isActive());
        }
        return PlanResponse.of(planRepo.save(p));
    }

    /** Mark one plan active and deactivate the user's other plans (only one "current" plan). */
    @Transactional
    public PlanResponse activatePlan(UUID userId, UUID planId) {
        WorkoutPlan target = requirePlan(userId, planId);
        for (WorkoutPlan p : planRepo.findByUserIdOrderByCreatedAtDesc(userId)) {
            if (Boolean.TRUE.equals(p.getIsActive()) && !p.getId().equals(planId)) {
                p.setIsActive(false);
                planRepo.save(p);
            }
        }
        target.setIsActive(true);
        return PlanResponse.of(planRepo.save(target));
    }

    @Transactional
    public void deletePlan(UUID userId, UUID planId) {
        requirePlan(userId, planId);
        for (WorkoutDay d : dayRepo.findByWorkoutPlanIdOrderByWeekNoAscDayNoAsc(planId)) {
            dayExerciseRepo.deleteByWorkoutDayId(d.getId());
        }
        dayRepo.deleteByWorkoutPlanId(planId);
        planRepo.deleteById(planId);
    }

    // ---------- days ----------

    @Transactional(readOnly = true)
    public List<DayResponse> listDays(UUID userId, UUID planId) {
        requirePlan(userId, planId);
        return dayRepo.findByWorkoutPlanIdOrderByWeekNoAscDayNoAsc(planId).stream().map(DayResponse::of).toList();
    }

    @Transactional
    public DayResponse addDay(UUID userId, UUID planId, DayRequest req) {
        requirePlan(userId, planId);
        List<WorkoutDay> existing = dayRepo.findByWorkoutPlanIdOrderByWeekNoAscDayNoAsc(planId);
        int nextDayNo = existing.stream().mapToInt(d -> d.getDayNo() == null ? 0 : d.getDayNo()).max().orElse(0) + 1;
        WorkoutDay d = new WorkoutDay();
        d.setWorkoutPlanId(planId);
        d.setWeekNo(req.weekNo() != null ? req.weekNo() : 1);
        d.setDayNo(req.dayNo() != null ? req.dayNo() : nextDayNo);
        d.setTitle(req.title());
        return DayResponse.of(dayRepo.save(d));
    }

    @Transactional
    public DayResponse updateDay(UUID userId, UUID dayId, DayRequest req) {
        WorkoutDay d = requireDay(userId, dayId);
        if (req.title() != null) {
            d.setTitle(req.title());
        }
        if (req.weekNo() != null) {
            d.setWeekNo(req.weekNo());
        }
        if (req.dayNo() != null) {
            d.setDayNo(req.dayNo());
        }
        return DayResponse.of(dayRepo.save(d));
    }

    @Transactional
    public void deleteDay(UUID userId, UUID dayId) {
        WorkoutDay d = requireDay(userId, dayId);
        dayExerciseRepo.deleteByWorkoutDayId(d.getId());
        dayRepo.deleteById(d.getId());
    }

    // ---------- day exercises ----------

    @Transactional(readOnly = true)
    public List<DayExerciseResponse> listDayExercises(UUID userId, UUID dayId) {
        requireDay(userId, dayId);
        List<WorkoutDayExercise> items = dayExerciseRepo.findByWorkoutDayIdOrderBySortOrderAsc(dayId);
        List<UUID> ids = items.stream().map(WorkoutDayExercise::getExerciseId).toList();
        Map<UUID, Exercise> byId = exerciseRepo.findAllById(ids).stream()
                .collect(Collectors.toMap(Exercise::getId, Function.identity()));
        return items.stream().map(w -> DayExerciseResponse.of(w, byId.get(w.getExerciseId()))).toList();
    }

    @Transactional
    public DayExerciseResponse addDayExercise(UUID userId, UUID dayId, DayExerciseRequest req) {
        requireDay(userId, dayId);
        Exercise ex = exerciseRepo.findById(req.exerciseId())
                .orElseThrow(() -> BusinessException.notFound("动作不存在"));
        List<WorkoutDayExercise> existing = dayExerciseRepo.findByWorkoutDayIdOrderBySortOrderAsc(dayId);
        int nextSort = existing.stream().mapToInt(w -> w.getSortOrder() == null ? 0 : w.getSortOrder()).max().orElse(0) + 1;
        WorkoutDayExercise w = new WorkoutDayExercise();
        w.setWorkoutDayId(dayId);
        w.setExerciseId(req.exerciseId());
        w.setSortOrder(req.sortOrder() != null ? req.sortOrder() : nextSort);
        w.setTargetSets(req.targetSets());
        w.setTargetReps(req.targetReps());
        w.setTargetWeight(req.targetWeight());
        if (req.restSeconds() != null) {
            w.setRestSeconds(req.restSeconds());
        }
        return DayExerciseResponse.of(dayExerciseRepo.save(w), ex);
    }

    @Transactional
    public void deleteDayExercise(UUID userId, UUID id) {
        WorkoutDayExercise w = dayExerciseRepo.findById(id)
                .orElseThrow(() -> BusinessException.notFound("记录不存在"));
        requireDay(userId, w.getWorkoutDayId());
        dayExerciseRepo.deleteById(id);
    }

    // ---------- ownership guards ----------

    private WorkoutPlan requirePlan(UUID userId, UUID planId) {
        WorkoutPlan p = planRepo.findById(planId).orElseThrow(() -> BusinessException.notFound("计划不存在"));
        if (!userId.equals(p.getUserId())) {
            throw new BusinessException(ResultCode.FORBIDDEN, "无权访问该计划");
        }
        return p;
    }

    private WorkoutDay requireDay(UUID userId, UUID dayId) {
        WorkoutDay d = dayRepo.findById(dayId).orElseThrow(() -> BusinessException.notFound("训练日不存在"));
        requirePlan(userId, d.getWorkoutPlanId());
        return d;
    }
}
