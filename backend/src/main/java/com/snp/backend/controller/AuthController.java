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

        // 3. If still not found, try finding by Display Name
        if (userOpt.isEmpty()) {
            userOpt = userRepository.findByDisplayName(request.getUsername());
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

        if (userRepository.findByEmail(request.getUsername()).isPresent()) {
            return ResponseEntity.badRequest().body("Username/Email already exists");
        }

        User user = new User();
        user.setEmail(request.getUsername()); // Use raw email/username

        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        user.setDisplayName(request.getName());

        // Map new fields
        user.setRegisterNumber(request.getRegisterNumber());
        user.setYear(request.getYear());
        user.setSection(request.getSection());
        user.setDepartment(request.getDepartment());
        user.setMobileNumber(request.getMobileNumber());

        if (request.getDomains() != null && !request.getDomains().isEmpty()) {
            user.setDomains(request.getDomains());

            // Auto-Admin Logic:
            // If the user registers for a domain that has NO users yet, they become ADMIN.
            // We check the FIRST selected domain for simplicity of this rule,
            // OR checks if any of them triggers it.
            // Let's stick to checking the primary (first) domain for the "Founder" effect.
            String primaryDomain = request.getDomains().get(0);
            long domainCount = userRepository.countByDomain(primaryDomain); // Mongo query matches array contains

            if (domainCount == 0) {
                user.setRole(User.Role.ADMIN);
            } else {
                user.setRole(User.Role.MEMBER);
            }
        } else {
            // Fallback
            if ("admin".equalsIgnoreCase(request.getUsername())) {
                user.setRole(User.Role.ADMIN);
            } else {
                user.setRole(User.Role.MEMBER);
            }
        }

        user.setAvatarUrl("https://api.dicebear.com/7.x/avataaars/png?seed=" + request.getUsername());
        user.setCreatedAt(java.time.Instant.now());

        userRepository.save(user);

        return ResponseEntity.ok("User registered successfully");
    }

}
