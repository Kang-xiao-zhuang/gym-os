package com.zk.gymos.repository;

import com.zk.gymos.entity.Exercise;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface ExerciseRepository extends JpaRepository<Exercise, UUID> {

    List<Exercise> findByBodyPart(String bodyPart);

    List<Exercise> findByNameContainingIgnoreCase(String keyword);
}
