package com.zk.gymos.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/** A body-metrics snapshot (table {@code body_measurements}), owned by {@link #userId}. */
@Getter
@Setter
@Entity
@Table(name = "body_measurements")
public class BodyMeasurement {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id")
    private UUID userId;

    private BigDecimal weight;

    @Column(name = "body_fat")
    private BigDecimal bodyFat;

    private BigDecimal chest;
    private BigDecimal waist;
    private BigDecimal hip;

    @Column(name = "arm_left")
    private BigDecimal armLeft;
    @Column(name = "arm_right")
    private BigDecimal armRight;
    @Column(name = "thigh_left")
    private BigDecimal thighLeft;
    @Column(name = "thigh_right")
    private BigDecimal thighRight;
    @Column(name = "calf_left")
    private BigDecimal calfLeft;
    @Column(name = "calf_right")
    private BigDecimal calfRight;

    @Column(name = "recorded_at")
    private OffsetDateTime recordedAt;

    @PrePersist
    void onCreate() {
        if (recordedAt == null) recordedAt = OffsetDateTime.now();
    }
}
