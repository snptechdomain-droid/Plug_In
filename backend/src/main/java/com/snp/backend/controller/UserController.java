package com.snp.backend.controller;

import com.snp.backend.model.User;
import com.snp.backend.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/users")
@CrossOrigin(origins = "*")
public class UserController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;

    private final Map<String, String> otpStore = new ConcurrentHashMap<>();

    @GetMapping
    public List<User> getAllUsers(@RequestParam(value = "viewerEmail", required = false) String viewerEmail) {
        User viewer = viewerEmail != null ? userRepository.findByEmail(viewerEmail).orElse(null) : null;
        List<User> users = userRepository.findAll();
        users.forEach(u -> u.setPasswordHash(null));

        if (viewer != null && viewer.getRole() == User.Role.LEAD && viewer.getDomain() != null) {
            return users.stream()
                    .filter(u -> viewer.getDomain().equals(u.getDomain()) || viewer.getEmail().equals(u.getEmail()))
                    .collect(Collectors.toList());
        }
        return users;
    }

    @GetMapping("/find")
    public User findUserByUsernameOrEmail(@RequestParam("query") String query,
            @RequestParam(value = "viewerEmail", required = false) String viewerEmail) {
        User viewer = viewerEmail != null ? userRepository.findByEmail(viewerEmail).orElse(null) : null;
        User target = userRepository.findByEmail(query)
                .or(() -> userRepository.findByDisplayName(query))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        if (viewer != null && viewer.getRole() == User.Role.LEAD && viewer.getDomain() != null
                && target.getDomain() != null && !viewer.getDomain().equals(target.getDomain())
                && !viewer.getEmail().equals(target.getEmail())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied for this profile");
        }
        target.setPasswordHash(null);
        return target;
    }

    @GetMapping("/members")
    public List<User> getMembers(@RequestParam(value = "viewerEmail", required = false) String viewerEmail) {
        User viewer = viewerEmail != null ? userRepository.findByEmail(viewerEmail).orElse(null) : null;
        List<User> members = userRepository.findByRole(User.Role.MEMBER);
        members.forEach(u -> u.setPasswordHash(null));

        if (viewer != null && viewer.getRole() == User.Role.LEAD && viewer.getDomain() != null) {
            return members.stream()
                    .filter(u -> viewer.getDomain().equals(u.getDomain()) || viewer.getEmail().equals(u.getEmail()))
                    .collect(Collectors.toList());
        }
        return members;
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
        String domainStr = roleMap.get("domain");
        try {
            User.Role newRole = User.Role.valueOf(newRoleStr);
            user.setRole(newRole);
            if (domainStr != null && !domainStr.isBlank()) {
                try {
                    user.setDomain(User.Domain.valueOf(domainStr.toUpperCase()));
                } catch (IllegalArgumentException e) {
                    // leave domain unchanged if invalid
                }
            } else if (newRole != User.Role.LEAD) {
                // Clear domain when demoting from lead
                user.setDomain(null);
            }
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

    @PostMapping("/forgot-password/request")
    public String requestPasswordReset(@RequestBody Map<String, String> payload) {
        String usernameOrEmail = payload.get("usernameOrEmail");
        if (usernameOrEmail == null || usernameOrEmail.isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Username or email required");
        }

        User user = userRepository.findByEmail(usernameOrEmail)
                .or(() -> userRepository.findByDisplayName(usernameOrEmail))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        // Mock OTP generation
        String otp = "123456";
        otpStore.put(user.getEmail(), otp);
        return "OTP generated";
    }

    @PostMapping("/forgot-password/verify")
    public String verifyOtp(@RequestBody Map<String, String> payload) {
        String usernameOrEmail = payload.get("usernameOrEmail");
        String otp = payload.get("otp");
        if (usernameOrEmail == null || otp == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid request");
        }

        User user = userRepository.findByEmail(usernameOrEmail)
                .or(() -> userRepository.findByDisplayName(usernameOrEmail))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        String storedOtp = otpStore.getOrDefault(user.getEmail(), "123456");
        if (!storedOtp.equals(otp)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid OTP");
        }
        return "OTP verified";
    }

    @PutMapping("/forgot-password/reset")
    public User resetPassword(@RequestBody Map<String, String> payload) {
        String usernameOrEmail = payload.get("usernameOrEmail");
        String otp = payload.get("otp");
        String newPassword = payload.get("newPassword");

        if (usernameOrEmail == null || otp == null || newPassword == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Missing fields");
        }

        User user = userRepository.findByEmail(usernameOrEmail)
                .or(() -> userRepository.findByDisplayName(usernameOrEmail))
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "User not found"));

        String storedOtp = otpStore.getOrDefault(user.getEmail(), "123456");
        if (!storedOtp.equals(otp)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid OTP");
        }

        user.setPasswordHash(passwordEncoder.encode(newPassword));
        otpStore.remove(user.getEmail());
        return userRepository.save(user);
    }
}
