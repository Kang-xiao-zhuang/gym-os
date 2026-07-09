package com.zk.gymos.dto;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/** Body of {@code POST /api/sessions}: finish today's workout with per-set logs. */
public record SessionRequest(

        @NotNull(message = "训练日不能为空")
        UUID workoutDayId,

        OffsetDateTime startedAt,

        Integer durationMinutes,

        /** Completed sets across all exercises. */
        List<LogEntry> logs
) {
    public record LogEntry(UUID exerciseId, Integer setNo, BigDecimal weight, Integer reps) {}
}
