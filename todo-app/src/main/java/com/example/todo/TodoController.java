package com.example.todo;

import java.net.URI;
import java.util.List;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import static org.springframework.http.HttpStatus.NOT_FOUND;

@RestController
@RequestMapping("/api/todos")
public class TodoController {
    private final TodoService todos;

    public TodoController(TodoService todos) {
        this.todos = todos;
    }

    @GetMapping
    public List<Todo> findAll() {
        return todos.findAll();
    }

    @GetMapping("/{id}")
    public Todo findById(@PathVariable long id) {
        return todos.findById(id).orElseThrow(() -> new ResponseStatusException(NOT_FOUND));
    }

    @PostMapping
    public ResponseEntity<Todo> create(@Valid @RequestBody TodoRequest request) {
        Todo created = todos.create(request);
        return ResponseEntity.created(URI.create("/api/todos/" + created.id())).body(created);
    }

    @PutMapping("/{id}")
    public Todo update(@PathVariable long id, @Valid @RequestBody TodoRequest request) {
        return todos.update(id, request)
                .orElseThrow(() -> new ResponseStatusException(NOT_FOUND));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable long id) {
        if (!todos.delete(id)) {
            throw new ResponseStatusException(NOT_FOUND);
        }
        return ResponseEntity.noContent().build();
    }
}
