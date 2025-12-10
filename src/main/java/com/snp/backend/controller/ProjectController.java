package com.snp.backend.controller;

import com.snp.backend.model.Poll;
import com.snp.backend.model.Project;
import com.snp.backend.model.User;
import com.snp.backend.repository.ProjectRepository;
import com.snp.backend.repository.UserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/projects")
@CrossOrigin(origins = "*")
public class ProjectController {

    @Autowired
    private ProjectRepository projectRepository;

    @Autowired
    private UserRepository userRepository;

    // Create a new project
    @PostMapping
    public ResponseEntity<Project> createProject(@RequestBody Map<String, String> payload) {
        String title = payload.get("title");
        String ownerId = payload.get("ownerId");

        if (title == null || ownerId == null) {
            return ResponseEntity.badRequest().build();
        }

        Project project = new Project();
        project.setTitle(title);
        project.setOwnerId(ownerId);
        project.setCollaboratorIds(new ArrayList<>());
        project.setPolls(new ArrayList<>());
        project.setCreatedAt(Instant.now());
        project.setUpdatedAt(Instant.now());

        Project savedProject = projectRepository.save(project);
        return ResponseEntity.ok(savedProject);
    }

    // Get all projects for a user (owned + collaborated)
    @GetMapping
    public ResponseEntity<List<Project>> getUserProjects(@RequestParam String userId) {
        List<Project> owned = projectRepository.findByOwnerId(userId);
        List<Project> collaborated = projectRepository.findByCollaboratorIdsContaining(userId);

        List<Project> all = new ArrayList<>();
        all.addAll(owned);
        all.addAll(collaborated);

        // Deduplicate just in case
        return ResponseEntity.ok(all.stream().distinct().collect(Collectors.toList()));
    }

    // Add a member to a project
    @PostMapping("/{projectId}/members")
    public ResponseEntity<?> addMember(@PathVariable String projectId, @RequestBody Map<String, String> payload) {
        String usernameToAdd = payload.get("username");

        Optional<Project> projectOpt = projectRepository.findById(projectId);
        if (projectOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        Optional<User> userOpt = userRepository.findByDisplayName(usernameToAdd);
        if (userOpt.isEmpty()) {
            // Try finding by email or username if displayName fails, but for now assume
            // username matches displayName or we need a better lookup
            // Let's try finding by username (which is email in our system usually, but
            // let's check User model)
            // User model has 'email' and 'displayName'.
            // If the input is an email, find by email.
            userOpt = userRepository.findByEmail(usernameToAdd);
        }

        if (userOpt.isEmpty()) {
            return ResponseEntity.badRequest().body("User not found");
        }

        Project project = projectOpt.get();
        String userIdToAdd = userOpt.get().getEmail(); // Use email as ID for simplicity in this app context

        if (!project.getCollaboratorIds().contains(userIdToAdd) && !project.getOwnerId().equals(userIdToAdd)) {
            project.getCollaboratorIds().add(userIdToAdd);
        }

        // Handle Role
        String role = payload.getOrDefault("role", "EDITOR");
        if (project.getMemberRoles() == null) {
            project.setMemberRoles(new java.util.HashMap<>());
        }
        project.getMemberRoles().put(userIdToAdd, role);

        projectRepository.save(project);

        return ResponseEntity.ok(project);
    }

    // Create a poll
    @PostMapping("/{projectId}/polls")
    public ResponseEntity<Project> createPoll(@PathVariable String projectId, @RequestBody Poll poll) {
        Optional<Project> projectOpt = projectRepository.findById(projectId);
        if (projectOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        Project project = projectOpt.get();
        if (project.getPolls() == null) {
            project.setPolls(new ArrayList<>());
        }

        // Ensure poll has ID and timestamp
        if (poll.getId() == null)
            poll.setId(java.util.UUID.randomUUID().toString());
        if (poll.getCreatedAt() == null)
            poll.setCreatedAt(Instant.now());
        poll.setActive(true);
        if (poll.getVotes() == null)
            poll.setVotes(new java.util.HashMap<>());

        project.getPolls().add(poll);
        Project saved = projectRepository.save(project);
        return ResponseEntity.ok(saved);
    }

    // Vote on a poll
    @PostMapping("/{projectId}/polls/{pollId}/vote")
    public ResponseEntity<Project> votePoll(@PathVariable String projectId, @PathVariable String pollId,
            @RequestBody Map<String, Object> payload) {
        try {
            System.out.println("DEBUG: Entering votePoll for pollId: " + pollId);

            String userId = (String) payload.get("userId");
            Object optionIdxObj = payload.get("optionIndex");

            if (optionIdxObj == null) {
                throw new IllegalArgumentException("optionIndex is required");
            }

            int optionIndex;
            if (optionIdxObj instanceof Number) {
                optionIndex = ((Number) optionIdxObj).intValue();
            } else {
                optionIndex = Integer.parseInt(optionIdxObj.toString());
            }

            System.out.println("DEBUG: Parsed optionIndex: " + optionIndex + ", userId: " + userId);

            Optional<Project> projectOpt = projectRepository.findById(projectId);
            if (projectOpt.isEmpty()) {
                return ResponseEntity.notFound().build();
            }

            Project project = projectOpt.get();
            Optional<Poll> pollOpt = project.getPolls().stream().filter(p -> p.getId().equals(pollId)).findFirst();

            if (pollOpt.isEmpty()) {
                return ResponseEntity.notFound().build();
            }

            Poll poll = pollOpt.get();
            if (!poll.isActive()) {
                return ResponseEntity.badRequest().body(project); // Poll closed
            }

            if (poll.getVotes() == null) {
                System.out.println("DEBUG: poll.getVotes() is null, initializing.");
                poll.setVotes(new java.util.HashMap<>());
            }

            // Handle migration: existing data could be Integer or List<Integer>
            List<Integer> userVotes = new ArrayList<>();
            Object rawVotes = poll.getVotes().get(userId);
            System.out.println(
                    "DEBUG: RawVotes for user: " + (rawVotes == null ? "null" : rawVotes.getClass().getName()));

            if (rawVotes instanceof Integer) {
                userVotes.add((Integer) rawVotes);
            } else if (rawVotes instanceof List) {
                List<?> list = (List<?>) rawVotes;
                for (Object o : list) {
                    if (o instanceof Integer) {
                        userVotes.add((Integer) o);
                    } else {
                        System.out.println("DEBUG: Found non-integer in vote list: "
                                + (o == null ? "null" : o.getClass().getName()));
                    }
                }
            }

            if (poll.isMultiSelect()) {
                // Toggle vote
                Integer val = Integer.valueOf(optionIndex);
                if (userVotes.contains(val)) {
                    userVotes.remove(val);
                } else {
                    userVotes.add(val);
                }
            } else {
                // Single select: replace
                userVotes.clear();
                userVotes.add(optionIndex);
            }

            // Remove entry if no votes left (optional, but cleaner)
            if (userVotes.isEmpty()) {
                poll.getVotes().remove(userId);
            } else {
                poll.getVotes().put(userId, userVotes);
            }

            Project saved = projectRepository.save(project);
            System.out.println("DEBUG: Project saved successfully.");
            return ResponseEntity.ok(saved);
        } catch (Exception e) {
            System.err.println("CRITICAL ERROR IN VOTE POLL:");
            e.printStackTrace();
            throw e;
        }
    }

    // Delete a poll
    @DeleteMapping("/{projectId}/polls/{pollId}")
    public ResponseEntity<Project> deletePoll(@PathVariable String projectId, @PathVariable String pollId) {
        Optional<Project> projectOpt = projectRepository.findById(projectId);
        if (projectOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        Project project = projectOpt.get();
        if (project.getPolls() == null) {
            return ResponseEntity.notFound().build();
        }

        boolean removed = project.getPolls().removeIf(p -> p.getId().equals(pollId));
        if (!removed) {
            return ResponseEntity.notFound().build();
        }

        Project saved = projectRepository.save(project);
        return ResponseEntity.ok(saved);
    }

    // Toggle poll status (Close/Open)
    @PutMapping("/{projectId}/polls/{pollId}/status")
    public ResponseEntity<Project> togglePollStatus(@PathVariable String projectId, @PathVariable String pollId) {
        Optional<Project> projectOpt = projectRepository.findById(projectId);
        if (projectOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        Project project = projectOpt.get();
        Optional<Poll> pollOpt = project.getPolls().stream().filter(p -> p.getId().equals(pollId)).findFirst();

        if (pollOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        Poll poll = pollOpt.get();
        poll.setActive(!poll.isActive()); // Toggle

        Project saved = projectRepository.save(project);
        return ResponseEntity.ok(saved);
    }

    // Update project data (tools)
    @PostMapping("/{projectId}/data")
    public ResponseEntity<Project> updateProjectData(@PathVariable String projectId,
            @RequestBody Map<String, String> payload) {
        Optional<Project> projectOpt = projectRepository.findById(projectId);
        if (projectOpt.isEmpty()) {
            return ResponseEntity.notFound().build();
        }

        Project project = projectOpt.get();
        if (payload.containsKey("flowchartData"))
            project.setFlowchartData(payload.get("flowchartData"));
        if (payload.containsKey("mindmapData"))
            project.setMindmapData(payload.get("mindmapData"));
        if (payload.containsKey("timelineData"))
            project.setTimelineData(payload.get("timelineData"));

        Project saved = projectRepository.save(project);
        return ResponseEntity.ok(saved);
    }
}
