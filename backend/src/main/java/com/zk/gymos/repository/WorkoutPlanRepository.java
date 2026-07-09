package com.zk.gymos.repository;

import com.zk.gymos.entity.WorkoutPlan;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface WorkoutPlanRepository extends JpaRepository<WorkoutPlan, UUID> {

    List<WorkoutPlan> findByUserIdOrderByCreatedAtDesc(UUID userId);
}
