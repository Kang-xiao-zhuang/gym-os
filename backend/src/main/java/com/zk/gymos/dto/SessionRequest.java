package com.zk.gymos.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/** Body of {@code POST /api/sessions}: finish a workout with per-set logs. workoutDayId is null for a freestyle (planless) session. */
public record SessionRequest(

        UUID workoutDayId,

        OffsetDateTime startedAt,

        Integer durationMinutes,

        /** Completed sets across all exercises. */
        List<LogEntry> logs
) {
    public record LogEntry(UUID exerciseId, Integer setNo, BigDecimal weight, Integer reps) {}
}
