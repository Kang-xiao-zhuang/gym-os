package com.zk.gymos.repository;

import com.zk.gymos.entity.WorkoutLog;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface WorkoutLogRepository extends JpaRepository<WorkoutLog, UUID> {

    List<WorkoutLog> findBySessionId(UUID sessionId);

    long countBySessionId(UUID sessionId);

    void deleteBySessionId(UUID sessionId);
}
