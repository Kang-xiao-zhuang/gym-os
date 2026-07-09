package com.zk.gymos.controller;

import com.zk.gymos.common.Result;
import com.zk.gymos.common.Results;
import com.zk.gymos.dto.MeasurementRequest;
import com.zk.gymos.dto.MeasurementResponse;
import com.zk.gymos.service.MeasurementService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/measurements")
public class MeasurementController {

    private final MeasurementService measurementService;

    public MeasurementController(MeasurementService measurementService) {
        this.measurementService = measurementService;
    }

    private static UUID uid(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }

    @GetMapping
    public Result<List<MeasurementResponse>> list(@AuthenticationPrincipal Jwt jwt) {
        return Results.success(measurementService.list(uid(jwt)));
    }

    @PostMapping
    public Result<MeasurementResponse> create(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody MeasurementRequest req) {
        return Results.success(measurementService.create(uid(jwt), req));
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        measurementService.delete(uid(jwt), id);
        return Results.success();
    }
}
