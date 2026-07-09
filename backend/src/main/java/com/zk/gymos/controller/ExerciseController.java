package com.zk.gymos.controller;

import com.zk.gymos.common.Result;
import com.zk.gymos.common.Results;
import com.zk.gymos.dto.ExerciseRequest;
import com.zk.gymos.dto.ExerciseResponse;
import com.zk.gymos.service.ExerciseService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/**
 * Exercise library. All endpoints require an authenticated Supabase user.
 * TODO: gate writes to admins once a custom role claim (app_metadata.role) is added.
 */
@RestController
@RequestMapping("/api/exercises")
public class ExerciseController {

    private final ExerciseService exerciseService;

    public ExerciseController(ExerciseService exerciseService) {
        this.exerciseService = exerciseService;
    }

    @GetMapping
    public Result<List<ExerciseResponse>> list(
            @RequestParam(required = false) String bodyPart,
            @RequestParam(required = false) String keyword) {
        return Results.success(exerciseService.list(bodyPart, keyword));
    }

    @GetMapping("/{id}")
    public Result<ExerciseResponse> get(@PathVariable UUID id) {
        return Results.success(exerciseService.get(id));
    }

    @PostMapping
    public Result<ExerciseResponse> create(@Valid @RequestBody ExerciseRequest req) {
        return Results.success(exerciseService.create(req));
    }

    @PutMapping("/{id}")
    public Result<ExerciseResponse> update(@PathVariable UUID id, @Valid @RequestBody ExerciseRequest req) {
        return Results.success(exerciseService.update(id, req));
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@PathVariable UUID id) {
        exerciseService.delete(id);
        return Results.success();
    }
}
