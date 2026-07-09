package com.zk.gymos.dto;

import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.util.UUID;

/** Body of {@code POST /api/days/{dayId}/exercises}. */
public record DayExerciseRequest(

        @NotNull(message = "动作不能为空")
        UUID exerciseId,

        Integer sortOrder,

        Integer targetSets,

        Integer targetReps,

        BigDecimal targetWeight,

        Integer restSeconds
) {
}
