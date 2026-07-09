package com.zk.gymos.service;

import com.zk.gymos.common.BusinessException;
import com.zk.gymos.dto.ExerciseRequest;
import com.zk.gymos.dto.ExerciseResponse;
import com.zk.gymos.entity.Exercise;
import com.zk.gymos.repository.ExerciseRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class ExerciseService {

    private final ExerciseRepository exerciseRepository;

    public ExerciseService(ExerciseRepository exerciseRepository) {
        this.exerciseRepository = exerciseRepository;
    }

    /** List the library, optionally filtered by body part or a name keyword. */
    @Transactional(readOnly = true)
    public List<ExerciseResponse> list(String bodyPart, String keyword) {
        List<Exercise> found;
        if (bodyPart != null && !bodyPart.isBlank()) {
            found = exerciseRepository.findByBodyPart(bodyPart.trim());
        } else if (keyword != null && !keyword.isBlank()) {
            found = exerciseRepository.findByNameContainingIgnoreCase(keyword.trim());
        } else {
            found = exerciseRepository.findAll();
        }
        return found.stream().map(ExerciseResponse::of).toList();
    }

    @Transactional(readOnly = true)
    public ExerciseResponse get(UUID id) {
        return ExerciseResponse.of(find(id));
    }

    @Transactional
    public ExerciseResponse create(ExerciseRequest req) {
        Exercise e = new Exercise();
        apply(e, req);
        return ExerciseResponse.of(exerciseRepository.save(e));
    }

    @Transactional
    public ExerciseResponse update(UUID id, ExerciseRequest req) {
        Exercise e = find(id);
        apply(e, req);
        return ExerciseResponse.of(exerciseRepository.save(e));
    }

    @Transactional
    public void delete(UUID id) {
        if (!exerciseRepository.existsById(id)) {
            throw BusinessException.notFound("动作不存在");
        }
        exerciseRepository.deleteById(id);
    }

    private Exercise find(UUID id) {
        return exerciseRepository.findById(id)
                .orElseThrow(() -> BusinessException.notFound("动作不存在"));
    }

    private void apply(Exercise e, ExerciseRequest req) {
        e.setName(req.name());
        e.setBodyPart(req.bodyPart());
        e.setEquipment(req.equipment());
        if (req.difficulty() != null) {
            e.setDifficulty(req.difficulty());
        }
        e.setDescription(req.description());
        e.setImageUrl(req.imageUrl());
        e.setVideoUrl(req.videoUrl());
    }
}
