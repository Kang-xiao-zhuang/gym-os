package com.zk.gymos.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * A single training day inside a plan (table {@code workout_days}). Has only a
 * {@code created_at} column (no updated_at), so it does not extend BaseEntity.
 */
@Getter
@Setter
@Entity
@Table(name = "workout_days")
public class WorkoutDay {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "workout_plan_id")
    private UUID workoutPlanId;

    @Column(name = "week_no", nullable = false)
    private Integer weekNo;

    @Column(name = "day_no", nullable = false)
    private Integer dayNo;

    @Column(length = 100)
    private String title;

    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = OffsetDateTime.now();
    }
}
