package com.zk.gymos.repository;

import com.zk.gymos.entity.WorkoutSession;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface WorkoutSessionRepository extends JpaRepository<WorkoutSession, UUID> {

    List<WorkoutSession> findByUserIdOrderByCreatedAtDesc(UUID userId);
}
