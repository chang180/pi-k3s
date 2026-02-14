<?php

namespace App\Http\Controllers\Api;

use App\Ai\Agents\PiK3sExplainer;
use App\Http\Controllers\Controller;
use App\Http\Requests\AiAskRequest;
use Laravel\Ai\Responses\StreamableAgentResponse;

class AiController extends Controller
{
    /**
     * POST /api/ai/ask - Stream AI response via SSE.
     */
    public function ask(AiAskRequest $request): StreamableAgentResponse
    {
        return (new PiK3sExplainer)->stream($request->validated('message'));
    }
}
