<?php

use App\Http\Controllers\Api\AiController;
use App\Http\Controllers\Api\CalculateController;
use App\Http\Controllers\Api\K8sStatusController;
use Illuminate\Support\Facades\Route;

Route::post('/calculate', [CalculateController::class, 'store']);
Route::get('/calculate/{calculation}', [CalculateController::class, 'show']);
Route::get('/calculate/{calculation}/stream', [CalculateController::class, 'stream']);
Route::get('/history', [CalculateController::class, 'history']);

Route::get('/k8s/status', [K8sStatusController::class, 'status']);
Route::get('/k8s/metrics', [K8sStatusController::class, 'metrics']);

Route::post('/ai/ask', [AiController::class, 'ask']);
