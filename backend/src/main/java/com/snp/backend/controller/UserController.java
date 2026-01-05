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
        System.out.println("Updating profile for: " + username);
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
        // New Fields
        if (updatedUser.getRegisterNumber() != null)
            user.setRegisterNumber(updatedUser.getRegisterNumber());
        if (updatedUser.getYear() != null)
            user.setYear(updatedUser.getYear());
        if (updatedUser.getSection() != null)
            user.setSection(updatedUser.getSection());
        if (updatedUser.getDepartment() != null)
            user.setDepartment(updatedUser.getDepartment());
        if (updatedUser.getMobileNumber() != null)
            user.setMobileNumber(updatedUser.getMobileNumber());
        if (updatedUser.getEmail() != null && !updatedUser.getEmail().equals(user.getEmail())) {
            // Check if new email is taken
            if (userRepository.findByEmail(updatedUser.getEmail()).isPresent()) {
                throw new RuntimeException("Email already in use");
            }
            user.setEmail(updatedUser.getEmail());
            // Note: If email is used as login username, this changes login credential.
        }

        // Domain update
        if (updatedUser.getDomains() != null) {
            user.setDomains(updatedUser.getDomains());
        }

        // Lead of Domain update with strict validation
        if (updatedUser.getLeadOfDomain() != null) {
            String newLeadDomain = updatedUser.getLeadOfDomain();

            // Allow clearing lead status by sending empty string
            if (!newLeadDomain.isEmpty()) {
                // 2. Check if THIS domain already has a lead
                try {
                    List<User> existingLeads = userRepository.findByLeadOfDomain(newLeadDomain);

                    // Filter out current user if they are already the lead (updating self)
                    existingLeads.removeIf(u -> u.getId().equals(user.getId()));

                    if (!existingLeads.isEmpty()) {
                        System.out.println("Conflict: Domain " + newLeadDomain + " already led by "
                                + existingLeads.get(0).getEmail());
                        throw new RuntimeException("Domain " + newLeadDomain + " already has a lead.");
                    }
                } catch (Exception e) {
                    System.out.println("Error verifying lead status: " + e.getMessage());
                    e.printStackTrace();
                    if (e instanceof RuntimeException) {
                        throw (RuntimeException) e;
                    }
                    throw new RuntimeException("Error verifying lead status: " + e.getMessage());
                }
            }
            user.setLeadOfDomain(newLeadDomain);
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
