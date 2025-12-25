package com.snp.backend.controller;

import com.snp.backend.model.User;
import com.snp.backend.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/users")
@CrossOrigin(origins = "*")
public class UserController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;

    @GetMapping
    public List<User> getAllUsers() {
        List<User> users = userRepository.findAll();
        users.forEach(u -> u.setPasswordHash(null));
        return users;
    }

    @PutMapping("/{username}")
    public User updateUserProfile(@PathVariable String username, @RequestBody User updatedUser) {
        User user = userRepository.findByEmail(username).orElse(null);

        if (user == null) {
            throw new RuntimeException("User not found");
        }

        if (updatedUser.getDisplayName() != null) {
            user.setDisplayName(updatedUser.getDisplayName());
        }
        if (updatedUser.getBio() != null) {
            user.setBio(updatedUser.getBio());
        }
        if (updatedUser.getAvatarUrl() != null) {
            user.setAvatarUrl(updatedUser.getAvatarUrl());
        }

        return userRepository.save(user);
    }

    @PutMapping("/{username}/password")
    public User changePassword(@PathVariable String username, @RequestBody java.util.Map<String, String> passwordMap) {
        User user = userRepository.findByEmail(username).orElse(null);

        if (user == null) {
            throw new RuntimeException("User not found");
        }

        String newPassword = passwordMap.get("newPassword");

        if (newPassword == null) {
            throw new RuntimeException("Missing new password");
        }

        // Direct password update without old password check
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        return userRepository.save(user);
    }

    @PutMapping("/{username}/role")
    public User changeUserRole(@PathVariable String username, @RequestBody Map<String, String> roleMap) {
        User user = userRepository.findByEmail(username).orElse(null);
        if (user == null) {
            throw new RuntimeException("User not found");
        }

        String newRoleStr = roleMap.get("role");
        try {
            User.Role newRole = User.Role.valueOf(newRoleStr);
            user.setRole(newRole);
            return userRepository.save(user);
        } catch (IllegalArgumentException e) {
            throw new RuntimeException("Invalid role");
        }
    }

    @DeleteMapping("/{username}")
    public void deleteUser(@PathVariable String username) {
        User user = userRepository.findByEmail(username).orElse(null);
        if (user != null) {
            userRepository.delete(user);
        }
    }
}
