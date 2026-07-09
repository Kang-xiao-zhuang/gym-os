package com.zk.gymos.controller;

import com.zk.gymos.common.Result;
import com.zk.gymos.common.Results;
import com.zk.gymos.dto.UserResponse;
import com.zk.gymos.service.UserService;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    /** Profile of the currently authenticated caller ({@code sub} claim of the Supabase JWT). */
    @GetMapping("/me")
    public Result<UserResponse> me(@AuthenticationPrincipal Jwt jwt) {
        return Results.success(userService.getById(UUID.fromString(jwt.getSubject())));
    }
}
