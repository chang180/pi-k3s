<script setup lang="ts">
import { ref } from 'vue';
import { Head } from '@inertiajs/vue3';
import AppLayout from '@/layouts/AppLayout.vue';
import { type BreadcrumbItem } from '@/types';

const breadcrumbs: BreadcrumbItem[] = [
    {
        title: 'Calculate Pi',
        href: '/calculate',
    },
];

const selectedPoints = ref<number>(100000);
const calculating = ref(false);
const result = ref<any>(null);
const error = ref<string | null>(null);
const queryId = ref<string>('');
const querying = ref(false);
const queryResult = ref<any>(null);
const queryError = ref<string | null>(null);

const pointsOptions = [
    { value: 100000, label: '10萬點 (100,000)' },
    { value: 1000000, label: '100萬點 (1,000,000)' },
    { value: 10000000, label: '1000萬點 (10,000,000)' },
];

async function calculate() {
    calculating.value = true;
    error.value = null;
    result.value = null;

    try {
        const response = await fetch('/api/calculate', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                Accept: 'application/json',
            },
            body: JSON.stringify({
                total_points: selectedPoints.value,
                mode: 'single',
            }),
        });

        const data = await response.json();

        if (!response.ok) {
            if (data.errors) {
                error.value = Object.values(data.errors).flat().join(', ');
            } else if (data.message) {
                error.value = data.message;
            } else {
                error.value = 'An error occurred during calculation';
            }
            return;
        }

        result.value = data;
    } catch (e) {
        error.value = e instanceof Error ? e.message : 'Network error';
    } finally {
        calculating.value = false;
    }
}

async function queryCalculation() {
    if (!queryId.value.trim()) {
        queryError.value = 'Please enter a calculation ID or UUID';
        return;
    }

    querying.value = true;
    queryError.value = null;
    queryResult.value = null;

    try {
        const response = await fetch(`/api/calculate/${queryId.value}`, {
            method: 'GET',
            headers: {
                Accept: 'application/json',
            },
        });

        const data = await response.json();

        if (!response.ok) {
            queryError.value = data.message || 'Calculation not found';
            return;
        }

        queryResult.value = data;
    } catch (e) {
        queryError.value = e instanceof Error ? e.message : 'Network error';
    } finally {
        querying.value = false;
    }
}

function formatNumber(num: number): string {
    return num.toLocaleString();
}
</script>

<template>
    <Head title="Calculate Pi" />

    <AppLayout :breadcrumbs="breadcrumbs">
        <div class="flex h-full flex-1 flex-col gap-6 overflow-x-auto p-6">
            <!-- Calculate Section -->
            <div
                class="rounded-xl border border-sidebar-border/70 bg-card p-6 dark:border-sidebar-border"
            >
                <h2 class="mb-4 text-2xl font-bold">
                    Calculate Pi using Monte Carlo Method
                </h2>

                <div class="mb-4">
                    <label class="mb-2 block text-sm font-medium"
                        >Select Number of Points</label
                    >
                    <select
                        v-model.number="selectedPoints"
                        class="w-full rounded-lg border border-input bg-background px-4 py-2"
                        :disabled="calculating"
                    >
                        <option
                            v-for="option in pointsOptions"
                            :key="option.value"
                            :value="option.value"
                        >
                            {{ option.label }}
                        </option>
                    </select>
                </div>

                <button
                    type="button"
                    class="rounded-lg bg-primary px-6 py-2 text-primary-foreground transition-colors hover:bg-primary/90 disabled:cursor-not-allowed disabled:opacity-50"
                    :disabled="calculating"
                    @click="calculate"
                >
                    {{ calculating ? 'Calculating...' : 'Calculate Pi' }}
                </button>

                <!-- Error Display -->
                <div
                    v-if="error"
                    class="mt-4 rounded-lg border border-destructive/50 bg-destructive/10 p-4 text-destructive"
                >
                    <p class="font-semibold">Error:</p>
                    <p>{{ error }}</p>
                </div>

                <!-- Result Display -->
                <div
                    v-if="result"
                    class="mt-6 rounded-lg border border-sidebar-border/70 bg-muted p-6 dark:border-sidebar-border"
                >
                    <h3 class="mb-4 text-xl font-semibold">Calculation Result</h3>
                    <div class="grid gap-3">
                        <div class="flex justify-between">
                            <span class="font-medium">ID:</span>
                            <span class="font-mono">{{ result.id }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="font-medium">UUID:</span>
                            <span class="font-mono text-sm">{{
                                result.uuid
                            }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="font-medium">Calculated Pi (π):</span>
                            <span class="text-lg font-bold text-primary">{{
                                result.result_pi
                            }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="font-medium">Duration:</span>
                            <span>{{ result.duration_ms }} ms</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="font-medium">Points Inside Circle:</span>
                            <span>{{ formatNumber(result.result_inside) }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="font-medium">Total Points:</span>
                            <span>{{ formatNumber(result.result_total) }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="font-medium">Status:</span>
                            <span
                                class="rounded-full px-2 py-1 text-xs font-semibold"
                                :class="{
                                    'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-100':
                                        result.status === 'completed',
                                    'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-100':
                                        result.status === 'running',
                                    'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-100':
                                        result.status === 'failed',
                                }"
                                >{{ result.status }}</span
                            >
                        </div>
                    </div>
                </div>
            </div>

            <!-- Query Section -->
            <div
                class="rounded-xl border border-sidebar-border/70 bg-card p-6 dark:border-sidebar-border"
            >
                <h2 class="mb-4 text-2xl font-bold">
                    Query Existing Calculation
                </h2>

                <div class="mb-4">
                    <label class="mb-2 block text-sm font-medium"
                        >Calculation ID or UUID</label
                    >
                    <input
                        v-model="queryId"
                        type="text"
                        placeholder="Enter ID or UUID"
                        class="w-full rounded-lg border border-input bg-background px-4 py-2"
                        :disabled="querying"
                        @keyup.enter="queryCalculation"
                    />
                </div>

                <button
                    type="button"
                    class="rounded-lg bg-secondary px-6 py-2 text-secondary-foreground transition-colors hover:bg-secondary/90 disabled:cursor-not-allowed disabled:opacity-50"
                    :disabled="querying"
                    @click="queryCalculation"
                >
                    {{ querying ? 'Querying...' : 'Query Calculation' }}
                </button>

                <!-- Query Error Display -->
                <div
                    v-if="queryError"
                    class="mt-4 rounded-lg border border-destructive/50 bg-destructive/10 p-4 text-destructive"
                >
                    <p class="font-semibold">Error:</p>
                    <p>{{ queryError }}</p>
                </div>

                <!-- Query Result Display -->
                <div
                    v-if="queryResult"
                    class="mt-6 rounded-lg border border-sidebar-border/70 bg-muted p-6 dark:border-sidebar-border"
                >
                    <h3 class="mb-4 text-xl font-semibold">Query Result</h3>
                    <div class="grid gap-3">
                        <div class="flex justify-between">
                            <span class="font-medium">ID:</span>
                            <span class="font-mono">{{ queryResult.id }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="font-medium">UUID:</span>
                            <span class="font-mono text-sm">{{
                                queryResult.uuid
                            }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="font-medium">Mode:</span>
                            <span>{{ queryResult.mode }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="font-medium">Status:</span>
                            <span
                                class="rounded-full px-2 py-1 text-xs font-semibold"
                                :class="{
                                    'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-100':
                                        queryResult.status === 'completed',
                                    'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-100':
                                        queryResult.status === 'running',
                                    'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-100':
                                        queryResult.status === 'failed',
                                }"
                                >{{ queryResult.status }}</span
                            >
                        </div>
                        <template v-if="queryResult.status === 'completed'">
                            <div class="flex justify-between">
                                <span class="font-medium"
                                    >Calculated Pi (π):</span
                                >
                                <span class="text-lg font-bold text-primary">{{
                                    queryResult.result_pi
                                }}</span>
                            </div>
                            <div class="flex justify-between">
                                <span class="font-medium">Duration:</span>
                                <span>{{ queryResult.duration_ms }} ms</span>
                            </div>
                            <div class="flex justify-between">
                                <span class="font-medium"
                                    >Points Inside Circle:</span
                                >
                                <span>{{
                                    formatNumber(queryResult.result_inside)
                                }}</span>
                            </div>
                            <div class="flex justify-between">
                                <span class="font-medium">Total Points:</span>
                                <span>{{
                                    formatNumber(queryResult.result_total)
                                }}</span>
                            </div>
                        </template>
                    </div>
                </div>
            </div>
        </div>
    </AppLayout>
</template>
