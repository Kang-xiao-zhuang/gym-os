package com.zk.gymos.controller;

import com.zk.gymos.common.Result;
import com.zk.gymos.common.Results;
import com.zk.gymos.dto.ExerciseTrendResponse;
import com.zk.gymos.dto.ImportResult;
import com.zk.gymos.dto.ImportSessionsRequest;
import com.zk.gymos.dto.InsightsResponse;
import com.zk.gymos.dto.LastPerformanceResponse;
import com.zk.gymos.dto.PrResponse;
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

    /** Latest logged performance of an exercise (data is null if never done). */
    @GetMapping("/last/{exerciseId}")
    public Result<LastPerformanceResponse> last(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID exerciseId) {
        return Results.success(sessionService.lastPerformance(uid(jwt), exerciseId));
    }

    /** Personal record of an exercise (data is null if never lifted with weight). */
    @GetMapping("/pr/{exerciseId}")
    public Result<PrResponse> pr(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID exerciseId) {
        return Results.success(sessionService.personalRecord(uid(jwt), exerciseId));
    }

    /** Per-session trend (max weight + volume) of an exercise, oldest→newest. */
    @GetMapping("/trend/{exerciseId}")
    public Result<ExerciseTrendResponse> trend(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID exerciseId) {
        return Results.success(sessionService.trend(uid(jwt), exerciseId));
    }

    /** Coaching insights: this-month body-part balance, plateaus, biggest recent gain. */
    @GetMapping("/insights")
    public Result<InsightsResponse> insights(@AuthenticationPrincipal Jwt jwt) {
        return Results.success(sessionService.insights(uid(jwt)));
    }

    /** Export ALL the user's training sessions with full per-set detail (front-end builds CSV/JSON). */
    @GetMapping("/export")
    public Result<List<SessionDetailResponse>> export(@AuthenticationPrincipal Jwt jwt) {
        return Results.success(sessionService.exportAll(uid(jwt)));
    }

    /** Import training sessions from a JSON backup (idempotent; duplicate sessions skipped). */
    @PostMapping("/import")
    public Result<ImportResult> importSessions(@AuthenticationPrincipal Jwt jwt, @RequestBody ImportSessionsRequest req) {
        return Results.success(sessionService.importSessions(uid(jwt), req.sessions()));
    }

    @DeleteMapping("/{id}")
    public Result<Void> delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        sessionService.delete(uid(jwt), id);
        return Results.success();
    }
}
