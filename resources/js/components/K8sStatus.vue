<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import type { K8sHpaEvent, K8sMetricsResponse, K8sStatusResponse } from '@/types';

const status = ref<K8sStatusResponse | null>(null);
const metrics = ref<K8sMetricsResponse | null>(null);
const error = ref<string | null>(null);

const scaleLog = ref<(K8sHpaEvent & { seenAt: string })[]>([]);
const seenEventKeys = new Set<string>();

let pollInterval: ReturnType<typeof setInterval> | null = null;

function eventKey(ev: K8sHpaEvent): string {
    return `${ev.reason}|${ev.timestamp}|${ev.count}`;
}

async function fetchData(): Promise<void> {
    try {
        const [statusRes, metricsRes, eventsRes] = await Promise.all([
            fetch('/api/k8s/status', { headers: { Accept: 'application/json' } }),
            fetch('/api/k8s/metrics', { headers: { Accept: 'application/json' } }),
            fetch('/api/k8s/events', { headers: { Accept: 'application/json' } }),
        ]);
        status.value = await statusRes.json();
        metrics.value = await metricsRes.json();
        error.value = null;

        const eventsData = await eventsRes.json();
        for (const ev of eventsData.events ?? []) {
            const key = eventKey(ev);
            if (!seenEventKeys.has(key)) {
                seenEventKeys.add(key);
                scaleLog.value.unshift({ ...ev, seenAt: new Date().toISOString() });
            }
        }
        if (scaleLog.value.length > 50) {
            scaleLog.value = scaleLog.value.slice(0, 50);
        }
    } catch (e) {
        error.value = e instanceof Error ? e.message : '無法取得 K8s 狀態';
    }
}

onMounted(() => {
    fetchData();
    pollInterval = setInterval(fetchData, 5000);
});

onUnmounted(() => {
    if (pollInterval) {
        clearInterval(pollInterval);
    }
});

const hpaActive = computed(() => (status.value?.hpa?.max_replicas ?? 0) > 0);

const replicaUtilization = computed(() => {
    const hpa = status.value?.hpa;
    if (!hpa || hpa.max_replicas === 0) {
        return 0;
    }
    return Math.round((hpa.current_replicas / hpa.max_replicas) * 100);
});

const workerPods = computed(() => (status.value?.pods ?? []).filter((pod) => pod.component === 'worker'));
const webPods = computed(() => (status.value?.pods ?? []).filter((pod) => pod.component === 'web'));

const hpaExpanded = computed(() => (status.value?.hpa?.current_replicas ?? 0) >= 2);

const cpuUtilization = computed(() => status.value?.hpa?.cpu_utilization ?? null);

const cpuBarColor = computed(() => {
    const cpu = cpuUtilization.value;
    if (cpu === null) return 'bg-neutral-400';
    if (cpu >= 30) return 'bg-red-500';
    if (cpu >= 20) return 'bg-yellow-500';
    return 'bg-sky-500';
});

const metricsByPodName = computed(() => {
    const map: Record<string, { cpu: string; memory: string }> = {};
    for (const pod of metrics.value?.pods ?? []) {
        map[pod.name] = { cpu: pod.cpu, memory: pod.memory };
    }
    return map;
});

const phaseColor: Record<string, string> = {
    Running: 'bg-green-500',
    Pending: 'bg-yellow-500',
    Succeeded: 'bg-blue-500',
    Failed: 'bg-red-500',
    Unknown: 'bg-neutral-400',
};

function shortName(name: string): string {
    const parts = name.split('-');
    if (parts.length <= 2) {
        return name;
    }
    return parts.slice(0, -2).join('-') + '-' + parts.slice(-1)[0].slice(0, 5);
}

function componentLabel(component: string): string {
    if (component === 'worker') return '計算';
    if (component === 'web') return 'Web';
    return component;
}

function formatTime(iso: string): string {
    if (!iso) return '—';
    const d = new Date(iso);
    return d.toLocaleTimeString('zh-TW', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}

function eventLabel(reason: string): string {
    if (reason === 'SuccessfulRescale') return '擴縮成功';
    if (reason === 'DesiredReplicas') return '目標副本';
    if (reason === 'FailedGetScale') return '取得規模失敗';
    return reason;
}

function isScaleUp(message: string): boolean {
    return /new size: [2-9]/i.test(message);
}

function isScaleDown(message: string): boolean {
    return /new size: 1/i.test(message);
}
</script>

<template>
    <div class="rounded-xl border border-sidebar-border/70 bg-card p-5 dark:border-sidebar-border">
        <div class="mb-4 flex items-center justify-between">
            <h3 class="text-lg font-semibold">Kubernetes 狀態</h3>
            <span
                v-if="status"
                class="rounded-full px-2 py-0.5 text-xs font-semibold"
                :class="
                    status.in_cluster
                        ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-100'
                        : 'bg-neutral-100 text-neutral-700 dark:bg-neutral-800 dark:text-neutral-300'
                "
            >
                {{ status.in_cluster ? 'In-Cluster' : '本機開發' }}
            </span>
        </div>

        <div v-if="error" class="rounded-lg border border-destructive/50 bg-destructive/10 p-3 text-sm text-destructive">
            {{ error }}
        </div>

        <template v-else-if="status">
            <!-- Not in cluster: show informative fallback -->
            <div v-if="!status.in_cluster" class="space-y-3">
                <div class="rounded-lg border border-dashed border-sidebar-border/70 bg-muted/50 p-4 text-sm text-muted-foreground dark:border-sidebar-border">
                    <p class="font-medium text-foreground">未在 K8s 叢集中執行</p>
                    <p class="mt-1 text-xs">
                        在本機開發模式下，K8s API 不可用。部署到 K3s 後可看到 Pod 副本、HPA 自動擴展、節點資源等即時資訊。
                    </p>
                </div>
                <div class="grid grid-cols-2 gap-3 opacity-50">
                    <div class="rounded-lg bg-muted p-3">
                        <div class="text-xs text-muted-foreground">Pod 數量</div>
                        <div class="text-2xl font-bold">—</div>
                    </div>
                    <div class="rounded-lg bg-muted p-3">
                        <div class="text-xs text-muted-foreground">HPA</div>
                        <div class="text-2xl font-bold">—</div>
                    </div>
                </div>
            </div>

            <!-- In-cluster: full status -->
            <template v-else>
                <!-- Summary tiles -->
                <div class="grid grid-cols-3 gap-3">
                    <div class="rounded-lg bg-muted p-3">
                        <div class="text-xs text-muted-foreground">總 Pod</div>
                        <div class="text-2xl font-bold">{{ status.pod_count }}</div>
                    </div>
                    <div class="rounded-lg bg-muted p-3">
                        <div class="text-xs text-muted-foreground">Web</div>
                        <div class="text-2xl font-bold">{{ status.web_pod_count }}</div>
                    </div>
                    <div class="rounded-lg bg-muted p-3">
                        <div class="text-xs text-muted-foreground">計算節點</div>
                        <div
                            class="text-2xl font-bold transition-colors"
                            :class="hpaExpanded ? 'text-green-600 dark:text-green-400' : ''"
                        >
                            {{ status.worker_pod_count }}
                        </div>
                    </div>
                </div>

                <!-- HPA details -->
                <div
                    v-if="hpaActive"
                    class="mt-4 rounded-lg border p-3"
                    :class="hpaExpanded ? 'border-green-500/40 bg-green-500/10' : 'border-sidebar-border/70 bg-muted'"
                >
                    <div class="mb-2 flex items-center justify-between text-xs">
                        <span class="text-muted-foreground">HPA 計算節點</span>
                        <span class="font-mono">
                            {{ status.hpa.current_replicas }} / {{ status.hpa.min_replicas }}–{{ status.hpa.max_replicas }}
                        </span>
                    </div>

                    <!-- Replica bar -->
                    <div class="h-2 overflow-hidden rounded-full bg-background">
                        <div
                            class="h-full rounded-full bg-linear-to-r from-sky-500 to-green-500 transition-all duration-500"
                            :style="{ width: `${replicaUtilization}%` }"
                        />
                    </div>

                    <!-- CPU utilization -->
                    <div v-if="cpuUtilization !== null" class="mt-3">
                        <div class="mb-1 flex items-center justify-between text-xs">
                            <span class="text-muted-foreground">Worker CPU 使用率</span>
                            <span
                                class="font-mono font-semibold"
                                :class="cpuUtilization >= 30 ? 'text-red-500' : cpuUtilization >= 20 ? 'text-yellow-500' : 'text-sky-500'"
                            >
                                {{ cpuUtilization }}% / 30% 門檻
                            </span>
                        </div>
                        <div class="h-2 overflow-hidden rounded-full bg-background">
                            <div
                                class="h-full rounded-full transition-all duration-500"
                                :class="cpuBarColor"
                                :style="{ width: `${Math.min(cpuUtilization, 100)}%` }"
                            />
                        </div>
                    </div>

                    <div class="mt-1.5 text-xs font-medium" :class="hpaExpanded ? 'text-green-700 dark:text-green-300' : 'text-muted-foreground'">
                        {{ hpaExpanded ? '已擴展到 2 個計算節點' : '待負載升高後擴展到第 2 個計算節點' }}
                    </div>
                    <div v-if="status.hpa.desired_replicas !== status.hpa.current_replicas" class="mt-1.5 text-xs text-muted-foreground">
                        目標副本：{{ status.hpa.desired_replicas }}（擴縮中）
                    </div>
                </div>

                <!-- Worker list -->
                <div v-if="workerPods.length" class="mt-4">
                    <h4 class="mb-2 text-sm font-medium">計算節點</h4>
                    <div class="space-y-1.5">
                        <div
                            v-for="pod in workerPods"
                            :key="pod.name"
                            class="flex items-center justify-between gap-2 rounded-lg bg-muted px-3 py-2 text-xs"
                        >
                            <div class="flex min-w-0 items-center gap-2">
                                <span
                                    class="size-2 shrink-0 rounded-full"
                                    :class="phaseColor[pod.phase] ?? 'bg-neutral-400'"
                                    :title="pod.phase"
                                />
                                <span class="truncate font-mono" :title="pod.name">{{ shortName(pod.name) }}</span>
                                <span
                                    v-if="!pod.ready"
                                    class="rounded bg-yellow-100 px-1 text-[10px] font-medium text-yellow-800 dark:bg-yellow-900 dark:text-yellow-100"
                                >
                                    未就緒
                                </span>
                            </div>
                            <div v-if="metricsByPodName[pod.name]" class="flex shrink-0 gap-3 text-muted-foreground">
                                <span>CPU：{{ metricsByPodName[pod.name].cpu }}</span>
                                <span>記憶體：{{ metricsByPodName[pod.name].memory }}</span>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Pod list -->
                <div v-if="webPods.length" class="mt-4">
                    <h4 class="mb-2 text-sm font-medium">Web Pod</h4>
                    <div class="space-y-1.5">
                        <div
                            v-for="pod in webPods"
                            :key="pod.name"
                            class="flex items-center justify-between gap-2 rounded-lg bg-muted px-3 py-2 text-xs"
                        >
                            <div class="flex min-w-0 items-center gap-2">
                                <span
                                    class="size-2 shrink-0 rounded-full"
                                    :class="phaseColor[pod.phase] ?? 'bg-neutral-400'"
                                    :title="pod.phase"
                                />
                                <span class="truncate font-mono" :title="pod.name">{{ shortName(pod.name) }}</span>
                                <span class="rounded bg-background px-1 text-[10px] font-medium text-muted-foreground">
                                    {{ componentLabel(pod.component) }}
                                </span>
                                <span
                                    v-if="!pod.ready"
                                    class="rounded bg-yellow-100 px-1 text-[10px] font-medium text-yellow-800 dark:bg-yellow-900 dark:text-yellow-100"
                                >
                                    未就緒
                                </span>
                            </div>
                            <div v-if="metricsByPodName[pod.name]" class="flex shrink-0 gap-3 text-muted-foreground">
                                <span>CPU：{{ metricsByPodName[pod.name].cpu }}</span>
                                <span>記憶體：{{ metricsByPodName[pod.name].memory }}</span>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- HPA Scale Event Log -->
                <div class="mt-4">
                    <div class="mb-2 flex items-center justify-between">
                        <h4 class="text-sm font-medium">HPA 擴縮事件記錄</h4>
                        <span class="text-xs text-muted-foreground">{{ scaleLog.length }} 筆</span>
                    </div>
                    <div
                        v-if="scaleLog.length === 0"
                        class="rounded-lg border border-dashed border-sidebar-border/70 p-3 text-center text-xs text-muted-foreground dark:border-sidebar-border"
                    >
                        尚無擴縮事件。以分散式模式計算 3000萬+ 點後，HPA 會在此記錄擴縮歷程。
                    </div>
                    <div v-else class="max-h-48 overflow-y-auto space-y-1.5 pr-1">
                        <div
                            v-for="(ev, i) in scaleLog"
                            :key="i"
                            class="flex items-start gap-2 rounded-lg px-3 py-2 text-xs"
                            :class="{
                                'bg-green-500/10 border border-green-500/20': isScaleUp(ev.message),
                                'bg-sky-500/10 border border-sky-500/20': isScaleDown(ev.message),
                                'bg-muted': !isScaleUp(ev.message) && !isScaleDown(ev.message),
                            }"
                        >
                            <span
                                class="mt-0.5 size-2 shrink-0 rounded-full"
                                :class="{
                                    'bg-green-500': isScaleUp(ev.message),
                                    'bg-sky-500': isScaleDown(ev.message),
                                    'bg-neutral-400': !isScaleUp(ev.message) && !isScaleDown(ev.message),
                                }"
                            />
                            <div class="min-w-0 flex-1">
                                <div class="flex items-center justify-between gap-2">
                                    <span class="font-medium">{{ eventLabel(ev.reason) }}</span>
                                    <span class="shrink-0 font-mono text-muted-foreground">{{ formatTime(ev.timestamp) }}</span>
                                </div>
                                <p class="mt-0.5 truncate text-muted-foreground" :title="ev.message">{{ ev.message }}</p>
                            </div>
                        </div>
                    </div>
                </div>
            </template>
        </template>

        <div v-else class="space-y-3">
            <div class="h-16 animate-pulse rounded-lg bg-muted" />
            <div class="h-16 animate-pulse rounded-lg bg-muted" />
        </div>
    </div>
</template>
