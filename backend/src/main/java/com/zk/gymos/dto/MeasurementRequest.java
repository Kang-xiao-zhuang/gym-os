package com.zk.gymos.dto;

import java.math.BigDecimal;

/** Body of {@code POST /api/measurements}. All fields optional; recordedAt defaults to now. */
public record MeasurementRequest(
        BigDecimal weight,
        BigDecimal bodyFat,
        BigDecimal chest,
        BigDecimal waist,
        BigDecimal hip,
        BigDecimal armLeft,
        BigDecimal armRight,
        BigDecimal thighLeft,
        BigDecimal thighRight,
        BigDecimal calfLeft,
        BigDecimal calfRight
) {
}
