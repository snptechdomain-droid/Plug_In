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
        // 1. Check if this is the very first user in the system
        boolean isFirstUser = userRepository.count() == 0;

        if (isFirstUser) {
            // AUTO-CREATE ADMIN (This is you!)
            request.setStatus("APPROVED");
            request.setRequestDate(LocalDateTime.now());
            MembershipRequest savedRequest = requestRepository.save(request);

            com.snp.backend.model.User newUser = new com.snp.backend.model.User();
            newUser.setDisplayName(request.getName());
            newUser.setEmail(request.getEmail());
            newUser.setRole(com.snp.backend.model.User.Role.ADMIN); // First user is always Boss
            newUser.setRegisterNumber(request.getRegisterNumber());

            // Setup Domain for the bright badges
            if (request.getDomain() != null) {
                try {
                    newUser.setDomain(com.snp.backend.model.User.Domain.valueOf(request.getDomain().toUpperCase().replace(" ", "_")));
                } catch (Exception e) { newUser.setDomain(com.snp.backend.model.User.Domain.TECH); }
            }

            // Password logic
            String rawPassword = (request.getRegisterNumber() != null && !request.getRegisterNumber().isEmpty())
                    ? request.getRegisterNumber() : "welcome123";
            newUser.setPasswordHash(passwordEncoder.encode(rawPassword));

            newUser.setActive(true);
            newUser.setCreatedAt(java.time.Instant.now());
            userRepository.save(newUser);

            System.out.println("First Admin created: " + newUser.getEmail());
            return savedRequest;

        } else {
            // NORMAL REQUEST (The second user and everyone else)
            request.setStatus("PENDING"); // They must wait for your permission
            request.setRequestDate(LocalDateTime.now());
            System.out.println("New application received from: " + request.getEmail() + ". Waiting for Admin approval.");
            return requestRepository.save(request);
        }
    }

    @PutMapping("/{id}/status")
    public MembershipRequest updateStatus(@PathVariable String id, @RequestBody String status) {
        String cleanStatus = status.replaceAll("\"", "").trim();

        return requestRepository.findById(id).map(request -> {
            request.setStatus(cleanStatus);

            if ("APPROVED".equals(cleanStatus)) {
                if (userRepository.findByEmail(request.getEmail()).isEmpty()) {
                    com.snp.backend.model.User newUser = new com.snp.backend.model.User();
                    newUser.setDisplayName(request.getName());
                    newUser.setEmail(request.getEmail());

                    // Set initial role as MEMBER (Admin can promote to LEAD later)
                    newUser.setRole(com.snp.backend.model.User.Role.MEMBER);

                    // Map the Domain from Request to User
                    if (request.getDomain() != null && !request.getDomain().isEmpty()) {
                        try {
                            String domainStr = request.getDomain().toUpperCase().replace(" ", "_");
                            newUser.setDomain(com.snp.backend.model.User.Domain.valueOf(domainStr));
                        } catch (IllegalArgumentException e) {
                            System.err.println("Invalid domain mapping: " + request.getDomain());
                        }
                    }

                    // Map specific fields so they appear in the Profile Screen
                    newUser.setRegisterNumber(request.getRegisterNumber());
                    newUser.setDepartment(request.getDepartment());
                    newUser.setYear(request.getYear());
                    newUser.setSection(request.getSection());

                    // Create the bio summary for the Admin/Lead view
                    String bio = String.format("Reg No: %s | %s %s-%s",
                            request.getRegisterNumber(), request.getDepartment(), request.getYear(), request.getSection());
                    newUser.setBio(bio);

                    // Password logic
                    String rawPassword = (request.getRegisterNumber() != null && !request.getRegisterNumber().isEmpty())
                            ? request.getRegisterNumber() : "welcome123";
                    newUser.setPasswordHash(passwordEncoder.encode(rawPassword));

                    newUser.setActive(true);
                    newUser.setCreatedAt(java.time.Instant.now());
                    userRepository.save(newUser);
                }
            }
            return requestRepository.save(request);
        }).orElseThrow(() -> new RuntimeException("Request not found"));
    }
}