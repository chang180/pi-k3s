<?php

use App\Ai\Agents\PiK3sExplainer;

test('ai ask returns streamed response', function () {
    PiK3sExplainer::fake(['這是蒙地卡羅法的說明。']);

    $response = $this->postJson('/api/ai/ask', [
        'message' => '什麼是蒙地卡羅法？',
    ]);

    $response->assertSuccessful();

    PiK3sExplainer::assertPrompted(fn ($prompt) => $prompt->contains('蒙地卡羅'));
});

test('ai ask validates message is required', function () {
    $response = $this->postJson('/api/ai/ask', []);

    $response->assertUnprocessable()
        ->assertJsonValidationErrors(['message']);
});

test('ai ask validates message max length', function () {
    $response = $this->postJson('/api/ai/ask', [
        'message' => str_repeat('a', 1001),
    ]);

    $response->assertUnprocessable()
        ->assertJsonValidationErrors(['message']);
});

test('ai ask accepts valid message', function () {
    PiK3sExplainer::fake(['回答內容']);

    $response = $this->postJson('/api/ai/ask', [
        'message' => 'HPA 是什麼？',
    ]);

    $response->assertSuccessful();

    PiK3sExplainer::assertPrompted(fn ($prompt) => $prompt->contains('HPA'));
});
