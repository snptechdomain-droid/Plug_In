package com.snp.backend.controller;

import com.snp.backend.model.MembershipRequest;
import com.snp.backend.repository.MembershipRequestRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/membership")
@CrossOrigin(origins = "*") // Allow all origins
public class MembershipRequestController {

    @Autowired
    private MembershipRequestRepository requestRepository;

    @Autowired
    private com.snp.backend.repository.UserRepository userRepository;

    @Autowired
    private org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;

    @GetMapping
    public List<MembershipRequest> getAllRequests() {
        return requestRepository.findAll();
    }

    @PostMapping("/request")
    public MembershipRequest submitRequest(@RequestBody MembershipRequest request) {
        request.setStatus("PENDING");
        request.setRequestDate(LocalDateTime.now());
        return requestRepository.save(request);
    }

    @PutMapping("/{id}/status")
    public MembershipRequest updateStatus(@PathVariable String id, @RequestBody String status) {
        String cleanStatus = status.replaceAll("\"", "").trim(); // Handle potential JSON quotes

        return requestRepository.findById(id).map(request -> {
            request.setStatus(cleanStatus);

            if ("APPROVED".equals(cleanStatus)) {
                // Check if user already exists
                if (userRepository.findByEmail(request.getEmail()).isEmpty()) {
                    com.snp.backend.model.User newUser = new com.snp.backend.model.User();
                    // newUser.setUsername(request.getEmail()); // Removed: Method undefined
                    // Generate username-based email for consistent login
                    String generatedUsername = request.getName().trim().replaceAll("\\s+", "").toLowerCase();
                    newUser.setEmail(generatedUsername + "@snp.com");
                    newUser.setDisplayName(request.getName());
                    newUser.setRole(com.snp.backend.model.User.Role.MEMBER);

                    // Set default password to Register Number, or "welcome123" if missing
                    String rawPassword = (request.getRegisterNumber() != null && !request.getRegisterNumber().isEmpty())
                            ? request.getRegisterNumber()
                            : "welcome123";

                    newUser.setPasswordHash(passwordEncoder.encode(rawPassword));
                    newUser.setActive(true);
                    newUser.setCreatedAt(java.time.Instant.now());

                    // Store original email and other details in bio
                    String bio = String.format("Email: %s | %s | %s %s %s",
                            request.getEmail(),
                            request.getRegisterNumber() != null ? request.getRegisterNumber() : "-",
                            request.getDepartment() != null ? request.getDepartment() : "",
                            request.getYear() != null ? request.getYear() : "",
                            request.getSection() != null ? request.getSection() : "");
                    newUser.setBio(bio);

                    userRepository.save(newUser);
                }
            }

            return requestRepository.save(request);
        }).orElseThrow(() -> new RuntimeException("Request not found"));
    }
}
