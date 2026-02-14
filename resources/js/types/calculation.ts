export type CalculationResult = {
    id: number;
    uuid: string;
    total_points: number;
    mode: 'single' | 'distributed';
    status: 'pending' | 'running' | 'completed' | 'failed';
    result_pi: number | null;
    result_inside: number | null;
    result_total: number | null;
    duration_ms: number | null;
    created_at: string;
    updated_at: string;
};

export type StreamUpdate = {
    id: number;
    uuid: string;
    status: string;
    completed_chunks: number;
    total_chunks: number;
    partial_pi: number;
    inside_count: number;
    total_count: number;
    result_pi: number | null;
    duration_ms: number | null;
};

export type PiHistoryEntry = {
    time: number;
    pi: number;
};

export type K8sStatusResponse = {
    in_cluster: boolean;
    pod_count: number;
    pods: Array<{
        name: string;
        status: string;
        ready: boolean;
        node: string;
    }>;
    hpa: {
        enabled: boolean;
        min_replicas?: number;
        max_replicas?: number;
        current_replicas?: number;
        cpu_target?: number;
        cpu_current?: number;
    } | null;
};

export type K8sMetricsResponse = {
    in_cluster: boolean;
    pods: Array<{
        name: string;
        cpu: string;
        memory: string;
    }>;
};

export type HistoryEntry = {
    id: number;
    uuid: string;
    total_points: number;
    mode: string;
    result_pi: number;
    duration_ms: number;
    created_at: string;
};
