package com.zk.gymos.controller;

import com.zk.gymos.common.Result;
import com.zk.gymos.common.Results;
import com.zk.gymos.dto.*;
import com.zk.gymos.service.WorkoutService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/** Training plans → days → day-exercises. All scoped to the authenticated user. */
@RestController
@RequestMapping("/api")
public class WorkoutController {

    private final WorkoutService workoutService;

    public WorkoutController(WorkoutService workoutService) {
        this.workoutService = workoutService;
    }

    private static UUID uid(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }

    // ----- plans -----

    @GetMapping("/plans")
    public Result<List<PlanResponse>> listPlans(@AuthenticationPrincipal Jwt jwt) {
        return Results.success(workoutService.listPlans(uid(jwt)));
    }

    @PostMapping("/plans")
    public Result<PlanResponse> createPlan(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody PlanRequest req) {
        return Results.success(workoutService.createPlan(uid(jwt), req));
    }

    @PutMapping("/plans/{planId}")
    public Result<PlanResponse> updatePlan(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID planId,
                                           @Valid @RequestBody PlanRequest req) {
        return Results.success(workoutService.updatePlan(uid(jwt), planId, req));
    }

    @DeleteMapping("/plans/{planId}")
    public Result<Void> deletePlan(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID planId) {
        workoutService.deletePlan(uid(jwt), planId);
        return Results.success();
    }

    @PostMapping("/plans/{planId}/activate")
    public Result<PlanResponse> activatePlan(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID planId) {
        return Results.success(workoutService.activatePlan(uid(jwt), planId));
    }

    /** Rolling "next up": the next training day to do in the active plan (null if none). */
    @GetMapping("/plans/next")
    public Result<NextUpResponse> nextUp(@AuthenticationPrincipal Jwt jwt) {
        return Results.success(workoutService.nextUp(uid(jwt)));
    }

    // ----- days -----

    @GetMapping("/plans/{planId}/days")
    public Result<List<DayResponse>> listDays(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID planId) {
        return Results.success(workoutService.listDays(uid(jwt), planId));
    }

    @PostMapping("/plans/{planId}/days")
    public Result<DayResponse> addDay(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID planId,
                                      @Valid @RequestBody DayRequest req) {
        return Results.success(workoutService.addDay(uid(jwt), planId, req));
    }

    @PutMapping("/days/{dayId}")
    public Result<DayResponse> updateDay(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID dayId,
                                         @Valid @RequestBody DayRequest req) {
        return Results.success(workoutService.updateDay(uid(jwt), dayId, req));
    }

    @DeleteMapping("/days/{dayId}")
    public Result<Void> deleteDay(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID dayId) {
        workoutService.deleteDay(uid(jwt), dayId);
        return Results.success();
    }

    // ----- day exercises -----

    @GetMapping("/days/{dayId}/exercises")
    public Result<List<DayExerciseResponse>> listDayExercises(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID dayId) {
        return Results.success(workoutService.listDayExercises(uid(jwt), dayId));
    }

    @PostMapping("/days/{dayId}/exercises")
    public Result<DayExerciseResponse> addDayExercise(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID dayId,
                                                      @Valid @RequestBody DayExerciseRequest req) {
        return Results.success(workoutService.addDayExercise(uid(jwt), dayId, req));
    }

    @DeleteMapping("/day-exercises/{id}")
    public Result<Void> deleteDayExercise(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        workoutService.deleteDayExercise(uid(jwt), id);
        return Results.success();
    }
}
