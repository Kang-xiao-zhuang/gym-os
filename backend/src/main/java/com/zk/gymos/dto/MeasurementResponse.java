package com.zk.gymos.dto;

import com.zk.gymos.entity.BodyMeasurement;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

public record MeasurementResponse(
        UUID id,
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
        BigDecimal calfRight,
        OffsetDateTime recordedAt
) {
    public static MeasurementResponse of(BodyMeasurement m) {
        return new MeasurementResponse(
                m.getId(), m.getWeight(), m.getBodyFat(), m.getChest(), m.getWaist(), m.getHip(),
                m.getArmLeft(), m.getArmRight(), m.getThighLeft(), m.getThighRight(),
                m.getCalfLeft(), m.getCalfRight(), m.getRecordedAt());
    }
}
