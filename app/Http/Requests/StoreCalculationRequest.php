<?php

namespace App\Http\Requests;

use App\Services\MonteCarloService;
use Illuminate\Foundation\Http\FormRequest;

class StoreCalculationRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'total_points' => 'required|integer|min:'.MonteCarloService::MIN_POINTS.'|max:'.MonteCarloService::MAX_POINTS,
            'mode' => 'sometimes|string|in:single,distributed',
        ];
    }

    /**
     * Get custom error messages for validation rules.
     *
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'total_points.required' => 'The total points field is required.',
            'total_points.integer' => 'The total points must be an integer.',
            'total_points.min' => 'The total points must be at least :min.',
            'total_points.max' => 'The total points must not exceed :max.',
            'mode.in' => 'The mode must be either single or distributed.',
        ];
    }

    /**
     * Prepare the data for validation.
     */
    protected function prepareForValidation(): void
    {
        if (! $this->has('mode')) {
            $this->merge(['mode' => 'single']);
        }
    }
}
