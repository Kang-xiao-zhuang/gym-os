package com.zk.gymos.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.util.UUID;

/**
 * A user's training plan (table {@code workout_plans}). Owned by {@link #userId}
 * (the Supabase Auth user id). Contains {@link WorkoutDay}s.
 */
@Getter
@Setter
@Entity
@Table(name = "workout_plans")
public class WorkoutPlan extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id")
    private UUID userId;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(columnDefinition = "text")
    private String description;

    @Column(name = "total_weeks")
    private Integer totalWeeks = 12;

    @Column(name = "is_active")
    private Boolean isActive = false;
}
