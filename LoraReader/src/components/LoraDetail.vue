<script setup>
import { defineProps, defineEmits } from 'vue';

const props = defineProps({
    lora: {
        type: Object,
        required: true
    },
    show: {
        type: Boolean,
        default: false
    }
});

const emit = defineEmits(['close']);

function handleOverlayClick(e) {
    if (e.target.classList.contains('overlay')) {
        emit('close');
    }
}
</script>

<template>
    <Transition name="fade">
        <div v-if="show" class="overlay" @click="handleOverlayClick">
            <div class="detail-card">
                <button class="close-btn" @click="$emit('close')">×</button>
                
                <div class="preview-section">
                    <img v-if="lora.has_preview" 
                         :src="`http://localhost:5000${lora.preview_path}`" 
                         :alt="lora.name" 
                         class="preview-image"
                    />
                    <div v-else class="no-preview">
                        无预览图
                    </div>
                </div>

                <div class="info-section">
                    <h2 class="title">{{ lora.name.replace('.safetensors', '') }}</h2>
                    
                    <div class="metadata-grid">
                        <div class="metadata-item">
                            <span class="label">适用版本</span>
                            <span class="value">{{ lora.metadata?.ss_base_model_version || 'Unknown' }}</span>
                        </div>
                        
                        <div class="metadata-item">
                            <span class="label">Module</span>
                            <span class="value">{{ lora.metadata?.ss_network_module || 'N/A' }}</span>
                        </div>
                        
                        <div class="metadata-item">
                            <span class="label">Dim</span>
                            <span class="value">{{ lora.metadata?.ss_network_dim || 'N/A' }}</span>
                        </div>
                        
                        <div class="metadata-item">
                            <span class="label">Alpha</span>
                            <span class="value">{{ lora.metadata?.ss_network_alpha || 'N/A' }}</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </Transition>
</template>

<style scoped>
.fade-enter-active,
.fade-leave-active {
    transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
    opacity: 0;
}

.overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
}

.detail-card {
    background: white;
    border-radius: 12px;
    width: 90%;
    max-width: 800px;
    max-height: 90vh;
    overflow-y: auto;
    position: relative;
    padding: 2rem;
    box-shadow: 0 8px 16px rgba(0, 0, 0, 0.2);
}

.close-btn {
    position: absolute;
    top: 1rem;
    right: 1rem;
    background: none;
    border: none;
    font-size: 1.5rem;
    cursor: pointer;
    color: #666;
    padding: 0.5rem;
    line-height: 1;
}

.preview-section {
    margin-bottom: 2rem;
    display: flex;
    justify-content: center;
}

.preview-image {
    max-width: 100%;
    max-height: 400px;
    object-fit: contain;
}

.no-preview {
    padding: 2rem;
    background: #f8f9fa;
    border-radius: 8px;
    color: #666;
}

.info-section {
    padding: 0 1rem;
}

.title {
    font-size: 1.5rem;
    margin-bottom: 1.5rem;
    color: #333;
}

.metadata-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 1rem;
}

.metadata-item {
    padding: 1rem;
    background: #f8f9fa;
    border-radius: 8px;
}

.label {
    display: block;
    font-size: 0.9rem;
    color: #666;
    margin-bottom: 0.5rem;
}

.value {
    font-size: 1.1rem;
    color: #333;
    font-weight: 500;
}
</style>
