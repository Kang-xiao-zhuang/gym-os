package com.zk.gymos.dto;

import jakarta.validation.constraints.NotNull;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/** Body of {@code POST /api/sessions}: finish today's workout. */
public record SessionRequest(

        @NotNull(message = "训练日不能为空")
        UUID workoutDayId,

        OffsetDateTime startedAt,

        Integer durationMinutes,

        /** Exercises that were completed. */
        List<UUID> exerciseIds
) {
}
