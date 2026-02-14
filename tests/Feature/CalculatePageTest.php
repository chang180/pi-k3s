<?php

test('calculate page renders successfully', function () {
    $response = $this->get('/calculate');

    $response->assertSuccessful();
});

test('calculate page renders as inertia page', function () {
    $response = $this->get('/calculate');

    $response->assertInertia(fn ($page) => $page->component('Calculate'));
});
