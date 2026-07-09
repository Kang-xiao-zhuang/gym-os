package com.zk.gymos.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/** One logged entry within a session (table {@code workout_logs}). */
@Getter
@Setter
@Entity
@Table(name = "workout_logs")
public class WorkoutLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "session_id")
    private UUID sessionId;

    @Column(name = "exercise_id")
    private UUID exerciseId;

    @Column(name = "set_no")
    private Integer setNo;

    private BigDecimal weight;
    private Integer reps;
    private Integer rir;

    @Column(name = "is_completed")
    private Boolean isCompleted = true;

    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @PrePersist
    void onCreate() {
        if (createdAt == null) createdAt = OffsetDateTime.now();
    }
}
