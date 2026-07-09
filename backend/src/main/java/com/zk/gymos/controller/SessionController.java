package com.zk.gymos.controller;

import com.zk.gymos.common.Result;
import com.zk.gymos.common.Results;
import com.zk.gymos.dto.SessionDetailResponse;
import com.zk.gymos.dto.SessionRequest;
import com.zk.gymos.dto.SessionResponse;
import com.zk.gymos.service.SessionService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/sessions")
public class SessionController {

    private final SessionService sessionService;

    public SessionController(SessionService sessionService) {
        this.sessionService = sessionService;
    }

    private static UUID uid(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }

    @GetMapping
    public Result<List<SessionResponse>> list(@AuthenticationPrincipal Jwt jwt) {
        return Results.success(sessionService.list(uid(jwt)));
    }

    @PostMapping
    public Result<SessionResponse> create(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody SessionRequest req) {
        return Results.success(sessionService.create(uid(jwt), req));
    }

    @GetMapping("/{id}")
    public Result<SessionDetailResponse> detail(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        return Results.success(sessionService.detail(uid(jwt), id));
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        sessionService.delete(uid(jwt), id);
        return Results.success();
    }
}
