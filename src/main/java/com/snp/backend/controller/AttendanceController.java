package com.snp.backend.controller;

import com.snp.backend.model.Attendance;
import com.snp.backend.repository.AttendanceRepository;
import lombok.Data;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Set;
import java.util.HashSet;

@RestController
@RequestMapping("/api/attendance")
@CrossOrigin(origins = "*")
public class AttendanceController {

    @Autowired
    private AttendanceRepository attendanceRepository;

    @Autowired
    private com.snp.backend.repository.UserRepository userRepository;

    @GetMapping
    public List<Attendance> getAllAttendance() {
        return attendanceRepository.findAllByOrderByDateDesc();
    }

    @PostMapping
    public Attendance markAttendance(@RequestBody Attendance attendance) {
        if (attendance.getDate() == null) {
            attendance.setDate(java.time.Instant.now());
        }
        return attendanceRepository.save(attendance);
    }

    @PutMapping("/{id}")
    public org.springframework.http.ResponseEntity<?> updateAttendance(@PathVariable String id,
            @RequestBody Attendance updatedAttendance) {
        return attendanceRepository.findById(id).map(attendance -> {
            java.time.Instant now = java.time.Instant.now();
            java.time.Instant attendanceTime = attendance.getDate();

            long minutesDiff = java.time.Duration.between(attendanceTime, now).toMinutes();

            if (minutesDiff > 60) {
                return org.springframework.http.ResponseEntity.status(403)
                        .body("Attendance cannot be edited after 1 hour.");
            }

            attendance.setPresentUserIds(updatedAttendance.getPresentUserIds());
            attendance.setNotes(updatedAttendance.getNotes());

            return org.springframework.http.ResponseEntity.ok(attendanceRepository.save(attendance));
        }).orElse(org.springframework.http.ResponseEntity.notFound().build());
    }

    @GetMapping("/user/{query}")
    public org.springframework.http.ResponseEntity<List<UserAttendanceDTO>> getUserAttendance(
            @PathVariable String query) {
        List<Attendance> allSessions = attendanceRepository.findAllByOrderByDateDesc();

        Set<String> searchIdentifiers = new HashSet<>();
        searchIdentifiers.add(query); // Always search for the raw query

        // Try to resolve user by Email
        userRepository.findByEmail(query).ifPresent(user -> {
            searchIdentifiers.add(user.getEmail());
            if (user.getDisplayName() != null)
                searchIdentifiers.add(user.getDisplayName());
        });

        // Try to resolve user by Display Name
        userRepository.findByDisplayName(query).ifPresent(user -> {
            searchIdentifiers.add(user.getEmail());
            if (user.getDisplayName() != null)
                searchIdentifiers.add(user.getDisplayName());
        });

        System.out.println("Searching attendance for identifiers: " + searchIdentifiers);

        List<UserAttendanceDTO> history = allSessions.stream().map(session -> {
            boolean isPresent = session.getPresentUserIds() != null &&
                    session.getPresentUserIds().stream().anyMatch(searchIdentifiers::contains);
            return new UserAttendanceDTO(
                    session.getId(),
                    session.getDate(),
                    session.getNotes(),
                    isPresent ? "PRESENT" : "ABSENT");
        }).collect(java.util.stream.Collectors.toList());

        return org.springframework.http.ResponseEntity.ok(history);
    }

    @Data
    public static class UserAttendanceDTO {
        private String sessionId;
        private java.time.Instant date;
        private String notes;
        private String status;

        public UserAttendanceDTO(String sessionId, java.time.Instant date, String notes, String status) {
            this.sessionId = sessionId;
            this.date = date;
            this.notes = notes;
            this.status = status;
        }
    }

    @DeleteMapping("/{id}")
    public org.springframework.http.ResponseEntity<?> deleteAttendance(@PathVariable String id) {
        if (attendanceRepository.existsById(id)) {
            attendanceRepository.deleteById(id);
            return org.springframework.http.ResponseEntity.ok().build();
        } else {
            return org.springframework.http.ResponseEntity.notFound().build();
        }
    }
}
