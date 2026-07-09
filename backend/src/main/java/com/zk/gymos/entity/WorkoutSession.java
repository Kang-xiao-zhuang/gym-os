package com.zk.gymos.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

/** One completed training session (table {@code workout_sessions}), owned by {@link #userId}. */
@Getter
@Setter
@Entity
@Table(name = "workout_sessions")
public class WorkoutSession {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "workout_day_id")
    private UUID workoutDayId;

    @Column(name = "started_at")
    private OffsetDateTime startedAt;

    @Column(name = "finished_at")
    private OffsetDateTime finishedAt;

    @Column(name = "duration_minutes")
    private Integer durationMinutes;

    private Integer calories;

    @Column(columnDefinition = "text")
    private String note;

    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = OffsetDateTime.now();
    }
}
