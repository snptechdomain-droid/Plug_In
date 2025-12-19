package com.snp.backend.controller;

import com.snp.backend.dto.LoginRequest;
import com.snp.backend.dto.RegisterRequest;
import com.snp.backend.model.User;
import com.snp.backend.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import com.snp.backend.service.RateLimitService;
import io.github.bucket4j.Bucket;
import jakarta.validation.Valid;

import java.util.Optional;

@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private RateLimitService rateLimitService;

    @PostMapping("/login")
    public ResponseEntity<?> login(@Valid @RequestBody LoginRequest request) {
        // Rate Limiting Check
        Bucket bucket = rateLimitService.resolveBucket(request.getUsername());
        if (!bucket.tryConsume(1)) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                    .body("Too many login attempts. Please try again later.");
        }

        // 1. Try finding by email (as provided)
        Optional<User> userOpt = userRepository.findByEmail(request.getUsername());

        // 2. If not found, try finding by constructed email (username + @snp.com)
        if (userOpt.isEmpty()) {
            userOpt = userRepository.findByEmail(request.getUsername() + "@snp.com");
        }

        // 3. Fake delay for timing attack mitigation (optional, keeping simple for now)

        if (userOpt.isPresent()) {
            User user = userOpt.get();
            if (user.getPasswordHash() != null
                    && passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
                return ResponseEntity.ok(user);
            } else {
                return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body("Invalid password");
            }
        } else {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body("Username/Email not found");
        }
    }

    @PostMapping("/register")
    public ResponseEntity<?> register(@Valid @RequestBody RegisterRequest request) {
        if (!"SnP_newmember".equals(request.getKey())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body("Invalid security key");
        }

        if (userRepository.findByEmail(request.getUsername() + "@snp.com").isPresent()) {
            return ResponseEntity.badRequest().body("Username already exists");
        }

        User user = new User();
        user.setEmail(request.getUsername() + "@snp.com");
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        user.setDisplayName(request.getUsername());

        if ("admin".equalsIgnoreCase(request.getUsername())) {
            user.setRole(User.Role.ADMIN);
        } else {
            user.setRole(User.Role.MEMBER);
        }

        user.setAvatarUrl("https://api.dicebear.com/7.x/avataaars/svg?seed=" + request.getUsername());
        user.setCreatedAt(java.time.Instant.now());

        userRepository.save(user);

        return ResponseEntity.ok("User registered successfully");
    }

}
