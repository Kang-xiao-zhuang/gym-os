package com.zk.gymos.service;

import com.zk.gymos.common.BusinessException;
import com.zk.gymos.dto.UserResponse;
import com.zk.gymos.repository.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public UserResponse getById(UUID id) {
        return userRepository.findById(id)
                .map(UserResponse::of)
                .orElseThrow(() -> BusinessException.notFound("用户资料不存在"));
    }
}
