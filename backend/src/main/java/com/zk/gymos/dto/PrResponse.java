package com.zk.gymos.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/** Personal record for an exercise: best weight ever lifted (+ reps at it) and best single-set volume. */
public record PrResponse(
        BigDecimal maxWeight,
        Integer maxWeightReps,
        BigDecimal bestSetVolume,
        OffsetDateTime achievedAt
) {
}
