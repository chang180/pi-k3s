<script setup lang="ts">
import { ref, computed } from 'vue';
import { Head } from '@inertiajs/vue3';
import AppLayout from '@/layouts/AppLayout.vue';
import ControlPanel from '@/components/ControlPanel.vue';
import MonteCarloCanvas from '@/components/MonteCarloCanvas.vue';
import PiChart from '@/components/PiChart.vue';
import K8sStatus from '@/components/K8sStatus.vue';
import PerformanceComparison from '@/components/PerformanceComparison.vue';
import AiChat from '@/components/AiChat.vue';
import { useCalculationStream } from '@/composables/useCalculationStream';
import type { BreadcrumbItem, CalculationResult } from '@/types';

const breadcrumbs: BreadcrumbItem[] = [
    { title: '計算 π', href: '/calculate' },
];

const selectedPoints = ref<number>(100000);
const selectedMode = ref<string>('single');
const calculating = ref(false);
const result = ref<CalculationResult | null>(null);
const error = ref<string | null>(null);

const { streamData, isStreaming, piHistory, startStream, stopStream } = useCalculationStream();

const performanceRef = ref<InstanceType<typeof PerformanceComparison> | null>(null);

// Query section
const queryId = ref('');
const querying = ref(false);
const queryResult = ref<CalculationResult | null>(null);
const queryError = ref<string | null>(null);

const displayPi = computed(() => {
    if (result.value?.result_pi) {
        return result.value.result_pi;
    }
    if (streamData.value?.partial_pi && streamData.value.partial_pi > 0) {
        return streamData.value.partial_pi;
    }
    return null;
});

const insideCount = computed(() => {
    if (result.value?.result_inside) {
        return result.value.result_inside;
    }
    return streamData.value?.inside_count ?? 0;
});

const totalCount = computed(() => {
    if (result.value?.result_total) {
        return result.value.result_total;
    }
    return streamData.value?.total_count ?? 0;
});

const progressPercent = computed(() => {
    if (!streamData.value || streamData.value.total_chunks === 0) {
        return 0;
    }
    return Math.round((streamData.value.completed_chunks / streamData.value.total_chunks) * 100);
});

async function handleStart(): Promise<void> {
    calculating.value = true;
    error.value = null;
    result.value = null;

    try {
        const response = await fetch('/api/calculate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
            body: JSON.stringify({
                total_points: selectedPoints.value,
                mode: selectedMode.value,
            }),
        });

        const data = await response.json();

        if (!response.ok) {
            if (data.errors) {
                error.value = Object.values(data.errors as Record<string, string[]>)
                    .flat()
                    .join(', ');
            } else {
                error.value = data.message || '發生錯誤';
            }
            calculating.value = false;
            return;
        }

        if (selectedMode.value === 'distributed') {
            startStream(data.id);
            calculating.value = false;
        } else {
            result.value = data;
            calculating.value = false;
            performanceRef.value?.refresh();
        }
    } catch (e) {
        error.value = e instanceof Error ? e.message : '網路錯誤';
        calculating.value = false;
    }
}

function handleStop(): void {
    stopStream();
    calculating.value = false;
}

function handleReset(): void {
    stopStream();
    calculating.value = false;
    result.value = null;
    error.value = null;
}

async function queryCalculation(): Promise<void> {
    if (!queryId.value.trim()) {
        queryError.value = '請輸入計算 ID 或 UUID';
        return;
    }

    querying.value = true;
    queryError.value = null;
    queryResult.value = null;

    try {
        const response = await fetch(`/api/calculate/${queryId.value}`, {
            headers: { Accept: 'application/json' },
        });

        const data = await response.json();

        if (!response.ok) {
            queryError.value = data.message || '找不到計算紀錄';
            return;
        }

        queryResult.value = data;
    } catch (e) {
        queryError.value = e instanceof Error ? e.message : '網路錯誤';
    } finally {
        querying.value = false;
    }
}

function formatNumber(num: number): string {
    return num.toLocaleString();
}
</script>

<template>
    <Head title="計算 π" />

    <AppLayout :breadcrumbs="breadcrumbs">
        <div class="flex h-full flex-1 flex-col gap-6 overflow-x-auto p-6">
            <!-- Top Row: Control Panel | Canvas | Live Result -->
            <div class="grid gap-6 lg:grid-cols-3">
                <ControlPanel
                    v-model:selected-points="selectedPoints"
                    v-model:selected-mode="selectedMode"
                    :calculating="calculating"
                    :is-streaming="isStreaming"
                    @start="handleStart"
                    @stop="handleStop"
                    @reset="handleReset"
                />

                <MonteCarloCanvas :inside-count="insideCount" :total-count="totalCount" />

                <!-- Live Result Card -->
                <div class="rounded-xl border border-sidebar-border/70 bg-card p-5 dark:border-sidebar-border">
                    <h3 class="mb-4 text-lg font-semibold">即時結果</h3>

                    <div v-if="error" class="rounded-lg border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
                        {{ error }}
                    </div>

                    <template v-else-if="displayPi">
                        <div class="mb-4 text-center">
                            <div class="text-xs text-muted-foreground">計算 π</div>
                            <div class="text-3xl font-bold text-primary">
                                {{ typeof displayPi === 'number' ? displayPi.toFixed(8) : displayPi }}
                            </div>
                            <div class="mt-1 text-xs text-muted-foreground">
                                實際 π = {{ Math.PI.toFixed(8) }}
                            </div>
                        </div>

                        <!-- Progress Bar (distributed mode) -->
                        <div v-if="isStreaming || (streamData && streamData.total_chunks > 0)" class="mb-4">
                            <div class="mb-1 flex justify-between text-xs text-muted-foreground">
                                <span>進度</span>
                                <span>{{ streamData?.completed_chunks ?? 0 }} / {{ streamData?.total_chunks ?? 0 }} 區塊</span>
                            </div>
                            <div class="h-2 overflow-hidden rounded-full bg-muted">
                                <div
                                    class="h-full rounded-full bg-primary transition-all duration-300"
                                    :style="{ width: `${progressPercent}%` }"
                                />
                            </div>
                        </div>

                        <div class="space-y-2 text-sm">
                            <div class="flex justify-between">
                                <span class="text-muted-foreground">圓內點數</span>
                                <span>{{ formatNumber(insideCount) }}</span>
                            </div>
                            <div class="flex justify-between">
                                <span class="text-muted-foreground">總點數</span>
                                <span>{{ formatNumber(totalCount) }}</span>
                            </div>
                            <div v-if="result?.duration_ms || streamData?.duration_ms" class="flex justify-between">
                                <span class="text-muted-foreground">耗時</span>
                                <span>{{ result?.duration_ms ?? streamData?.duration_ms }} ms</span>
                            </div>
                            <div v-if="result?.status || streamData?.status" class="flex justify-between">
                                <span class="text-muted-foreground">狀態</span>
                                <span
                                    class="rounded-full px-2 py-0.5 text-xs font-semibold"
                                    :class="{
                                        'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-100':
                                            (result?.status ?? streamData?.status) === 'completed',
                                        'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-100':
                                            (result?.status ?? streamData?.status) === 'running',
                                        'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-100':
                                            (result?.status ?? streamData?.status) === 'failed',
                                    }"
                                >{{ result?.status ?? streamData?.status }}</span>
                            </div>
                        </div>
                    </template>

                    <div v-else class="flex h-40 items-center justify-center text-sm text-muted-foreground">
                        請設定參數並開始計算
                    </div>
                </div>
            </div>

            <!-- Pi Convergence Chart -->
            <PiChart v-if="piHistory.length > 0" :pi-history="piHistory" />

            <!-- Bottom Row: K8s Status | Performance Comparison -->
            <div class="grid gap-6 md:grid-cols-2">
                <K8sStatus />
                <PerformanceComparison ref="performanceRef" />
            </div>

            <!-- AI Chat -->
            <AiChat />

            <!-- Query Section -->
            <div class="rounded-xl border border-sidebar-border/70 bg-card p-6 dark:border-sidebar-border">
                <h2 class="mb-4 text-2xl font-bold">查詢歷史計算</h2>

                <div class="mb-4">
                    <label class="mb-2 block text-sm font-medium">計算 ID 或 UUID</label>
                    <input
                        v-model="queryId"
                        type="text"
                        placeholder="輸入 ID 或 UUID"
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
                    {{ querying ? '查詢中...' : '查詢計算' }}
                </button>

                <div
                    v-if="queryError"
                    class="mt-4 rounded-lg border border-destructive/50 bg-destructive/10 p-4 text-destructive"
                >
                    <p class="font-semibold">錯誤：</p>
                    <p>{{ queryError }}</p>
                </div>

                <div
                    v-if="queryResult"
                    class="mt-6 rounded-lg border border-sidebar-border/70 bg-muted p-6 dark:border-sidebar-border"
                >
                    <h3 class="mb-4 text-xl font-semibold">查詢結果</h3>
                    <div class="grid gap-3">
                        <div class="flex justify-between">
                            <span class="font-medium">ID：</span>
                            <span class="font-mono">{{ queryResult.id }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="font-medium">UUID：</span>
                            <span class="font-mono text-sm">{{ queryResult.uuid }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="font-medium">模式：</span>
                            <span>{{ queryResult.mode }}</span>
                        </div>
                        <div class="flex justify-between">
                            <span class="font-medium">狀態：</span>
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
                            >{{ queryResult.status }}</span>
                        </div>
                        <template v-if="queryResult.status === 'completed'">
                            <div class="flex justify-between">
                                <span class="font-medium">計算 π：</span>
                                <span class="text-lg font-bold text-primary">{{ queryResult.result_pi }}</span>
                            </div>
                            <div class="flex justify-between">
                                <span class="font-medium">耗時：</span>
                                <span>{{ queryResult.duration_ms }} ms</span>
                            </div>
                            <div class="flex justify-between">
                                <span class="font-medium">圓內點數：</span>
                                <span>{{ formatNumber(queryResult.result_inside ?? 0) }}</span>
                            </div>
                            <div class="flex justify-between">
                                <span class="font-medium">總點數：</span>
                                <span>{{ formatNumber(queryResult.result_total ?? 0) }}</span>
                            </div>
                        </template>
                    </div>
                </div>
            </div>
        </div>
    </AppLayout>
</template>
