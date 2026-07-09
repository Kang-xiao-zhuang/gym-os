package com.zk.gymos.service;

import com.zk.gymos.common.BusinessException;
import com.zk.gymos.common.ResultCode;
import com.zk.gymos.dto.MeasurementRequest;
import com.zk.gymos.dto.MeasurementResponse;
import com.zk.gymos.entity.BodyMeasurement;
import com.zk.gymos.repository.BodyMeasurementRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class MeasurementService {

    private final BodyMeasurementRepository repo;

    public MeasurementService(BodyMeasurementRepository repo) {
        this.repo = repo;
    }

    /** Chronological (oldest → newest) so the client can chart directly. */
    @Transactional(readOnly = true)
    public List<MeasurementResponse> list(UUID userId) {
        return repo.findByUserIdOrderByRecordedAtAsc(userId).stream().map(MeasurementResponse::of).toList();
    }

    @Transactional
    public MeasurementResponse create(UUID userId, MeasurementRequest req) {
        BodyMeasurement m = new BodyMeasurement();
        m.setUserId(userId);
        m.setWeight(req.weight());
        m.setBodyFat(req.bodyFat());
        m.setChest(req.chest());
        m.setWaist(req.waist());
        m.setHip(req.hip());
        m.setArmLeft(req.armLeft());
        m.setArmRight(req.armRight());
        m.setThighLeft(req.thighLeft());
        m.setThighRight(req.thighRight());
        m.setCalfLeft(req.calfLeft());
        m.setCalfRight(req.calfRight());
        return MeasurementResponse.of(repo.save(m));
    }

    @Transactional
    public void delete(UUID userId, UUID id) {
        BodyMeasurement m = repo.findById(id).orElseThrow(() -> BusinessException.notFound("记录不存在"));
        if (!userId.equals(m.getUserId())) {
            throw new BusinessException(ResultCode.FORBIDDEN, "无权删除");
        }
        repo.deleteById(id);
    }
}
