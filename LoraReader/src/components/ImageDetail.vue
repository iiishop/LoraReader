<script setup>
import { ref, watch } from 'vue';
import { globalState, findLorasByName } from '../utils/globalVar';
import LoraSearchResult from './detailComp/LoraSearchResult.vue';

const props = defineProps({
    imageUrl: {
        type: String,
        required: true
    },
    show: {
        type: Boolean,
        default: false
    }
});

const emit = defineEmits(['close-image-detail']);

const positivePrompt = ref('');
const negativePrompt = ref('');
const errorMessage = ref('');
const showPositiveCopySuccess = ref(false);
const showNegativeCopySuccess = ref(false);

const generationParams = ref({
    steps: null,
    sampler: null,
    cfgScale: null,
    seed: null,
    size: null,
    modelHash: null,
    model: null,
    denoisingStrength: null,
    clipSkip: null,
    hiresUpscale: null,
    hiresSteps: null,
    hiresUpscaler: null,
    loraHashes: [],
    version: null
});

watch(() => props.imageUrl, async (newUrl) => {
    if (newUrl) {
        await parseImage(newUrl);
    }
}, { immediate: true });

// 添加文本清理函数
function cleanText(text) {
    // 基本清理
    return text
        // 替换零宽字符
        .replace(/[\u200B-\u200D\uFEFF]/g, '')
        // 替换不可打印字符 (控制字符)
        .replace(/[\x00-\x1F\x7F]/g, '')
        // 替换特殊空格
        .replace(/[\u2000-\u200F\u2028-\u202F\u205F-\u206F]/g, ' ')
        // 规范化空格和换行
        .replace(/\s+/g, ' ')
        .trim();
}

// 添加 LoRA 信息解析函数
function findCompleteJsonObjects(text) {
    const results = [];
    let i = 0;
    
    while (i < text.length) {
        // 寻找模式 "数字":{
        const nodeMatch = text.slice(i).match(/"(\d+)":\s*\{/);
        if (!nodeMatch) break;
        
        const nodeId = nodeMatch[1];
        const startIndex = i + nodeMatch.index;
        const contentStart = startIndex + nodeMatch[0].length - 1; // -1 是为了包含 {
        
        // 从内容开始处寻找匹配的结束括号
        let bracketCount = 1;
        let j = contentStart + 1;
        
        while (j < text.length && bracketCount > 0) {
            if (text[j] === '{') bracketCount++;
            if (text[j] === '}') bracketCount--;
            j++;
        }
        
        if (bracketCount === 0) {
            // 提取完整的 JSON 对象
            const jsonContent = text.slice(contentStart, j);
            try {
                const parsed = JSON.parse(jsonContent);
                results.push({
                    nodeId,
                    content: parsed
                });
            } catch (e) {
                console.error(`Error parsing node ${nodeId}:`, e);
            }
        }
        
        i = j; // 移动到当前对象之后继续搜索
    }
    
    return results;
}

function extractLoraWeightsFromPrompt(prompt) {
    const weights = {};
    const loraPattern = /<([^:]+):([^>]+)>/g;
    let match;
    
    while ((match = loraPattern.exec(prompt)) !== null) {
        const [, name, weight] = match;
        weights[name] = parseFloat(weight) || 1.0;
    }
    
    return weights;
}

function parseAllLoraInfo(text) {
    console.log('Starting LoRA parsing...');
    const loras = [];
    const loraWeights = {};
    
    // 提取提示词中的 LoRA 权重
    if (positivePrompt.value) {
        Object.assign(loraWeights, extractLoraWeightsFromPrompt(positivePrompt.value));
    }
    if (negativePrompt.value) {
        Object.assign(loraWeights, extractLoraWeightsFromPrompt(negativePrompt.value));
    }
    
    // 1. 尝试解析 ComfyUI 格式
    try {
        console.log('Attempting to parse ComfyUI format...');
        
        // 使用新的方法查找所有完整的 JSON 对象
        const nodes = findCompleteJsonObjects(text);
        console.log('Found nodes:', nodes.length);
        
        for (const node of nodes) {
            try {
                console.log('Processing node:', node.nodeId);
                const nodeData = node.content;
                
                // 检查是否是 LoRA Stacker 节点
                if (nodeData.class_type === 'LoRA Stacker' && nodeData.inputs) {
                    console.log('Found LoRA Stacker node:', nodeData);
                    
                    const loraCount = parseInt(nodeData.inputs.lora_count) || 0;
                    console.log('LoRA count:', loraCount);

                    for (let i = 1; i <= loraCount; i++) {
                        const nameKey = `lora_name_${i}`;
                        const weightKey = `lora_wt_${i}`;
                        const name = nodeData.inputs[nameKey];
                        const weight = nodeData.inputs[weightKey];

                        if (!name || name === 'None') {
                            console.log(`Skipping empty or None LoRA at index ${i}`);
                            continue;
                        }

                        const cleanName = name.split(/[/\\]/).pop()?.replace('.safetensors', '') || name;
                        const parsedWeight = parseFloat(weight) || 1.0;

                        console.log(`Processing LoRA ${i}:`, {
                            originalName: name,
                            cleanName: cleanName,
                            weight: parsedWeight
                        });

                        loras.push({
                            name: cleanName,
                            weight: parsedWeight,
                            source: 'comfyui',
                            originalPath: name
                        });
                    }
                }
            } catch (parseError) {
                console.log(`Error processing node ${node.nodeId}:`, parseError);
                continue;
            }
        }
    } catch (error) {
        console.error('Error parsing ComfyUI LoRA info:', error);
        console.log('Error context:', {
            errorName: error.name,
            errorMessage: error.message,
            errorStack: error.stack
        });
    }
    
    // 2. 尝试解析 WebUI 格式
    try {
        const loraHashes = text.match(/Lora hashes:\s*"([^"]+)"/)?.[1]?.split(', ') || [];
        for (const hash of loraHashes) {
            const [name, hashValue] = hash.split(':');
            if (name) {
                const cleanName = name.replace(/^(?:lora|lyco)_/, '');
                // 添加从提示词中提取的权重
                const weight = loraWeights[cleanName] || 1.0;
                loras.push({
                    name: cleanName,
                    hash: hashValue,
                    weight: weight,  // 添加权重
                    source: 'webui'
                });
            }
        }
    } catch (error) {
        console.error('Error parsing WebUI LoRA hashes:', error);
    }

    console.log('Final parsed LoRAs:', loras);
    return loras;
}

async function parseImage(url) {
    try {
        const response = await fetch(url);
        const blob = await response.blob();
        const text = await blob.text();
        console.log('Image metadata length:', text.length);

        // 查找所有节点
        const nodeMatches = text.match(/"(\d+)":\s*({[^}]+})/g);
        if (nodeMatches) {
            console.log('Found nodes:', nodeMatches.length);
            console.log('First node sample:', nodeMatches[0].substring(0, 100));
        }

        // 打印更多信息来定位问题
        console.log('Looking for LoRA Stacker pattern...');
        
        // 尝试用不同的方式匹配 LoRA 相关内容
        const stackerIndex = text.indexOf('LoRA Stacker');
        if (stackerIndex !== -1) {
            console.log('Found LoRA Stacker at index:', stackerIndex);
            // 显示上下文
            console.log('Context around LoRA Stacker:', 
                text.substring(Math.max(0, stackerIndex - 100), 
                             Math.min(text.length, stackerIndex + 100))
            );
        }

        // 尝试查找 inputs 和 class_type
        const inputsIndex = text.indexOf('"inputs"');
        const classTypeIndex = text.indexOf('"class_type"');
        
        if (inputsIndex !== -1) {
            console.log('Found "inputs" at index:', inputsIndex);
            console.log('Context around inputs:', 
                text.substring(Math.max(0, inputsIndex - 50), 
                             Math.min(text.length, inputsIndex + 50))
            );
        }
        
        if (classTypeIndex !== -1) {
            console.log('Found "class_type" at index:', classTypeIndex);
            console.log('Context around class_type:', 
                text.substring(Math.max(0, classTypeIndex - 50), 
                             Math.min(text.length, classTypeIndex + 50))
            );
        }

        // 修改正则表达式的匹配模式，使其更宽松
        const stackerRegex = /"(\d+)":\s*(\{[^{}]*"class_type"\s*:\s*"LoRA Stacker"[^}]*\})/g;
        const matches = Array.from(text.matchAll(stackerRegex));
        console.log('LoRA Stacker regex matches:', matches.length);

        if (matches.length > 0) {
            matches.forEach((match, i) => {
                console.log(`Match ${i + 1}:`, {
                    nodeId: match[1],
                    content: match[2].substring(0, 100) + '...'
                });
            });
        }

        // 尝试查找任何包含 "LoRA" 或 "Stacker" 的内容
        const loraRelated = text.match(/.{0,50}(LoRA|Stacker).{0,50}/g);
        if (loraRelated) {
            console.log('Found LoRA related content:', loraRelated);
        }

        let hasAnyValidData = false;

        // 解析提示词
        const positiveMatch = text.match(/parameters\s*([\s\S]*?)Negative prompt:/);
        const negativeMatch = text.match(/Negative prompt:\s*([\s\S]*?)Steps:/);
        
        if (positiveMatch) {
            positivePrompt.value = cleanText(positiveMatch[1].trim());
            hasAnyValidData = true;
        }
        
        if (negativeMatch) {
            negativePrompt.value = cleanText(negativeMatch[1].trim());
            hasAnyValidData = true;
        }

        // 如果没有找到标准格式，尝试JSON格式
        if (!positiveMatch || !negativeMatch) {
            const positiveJsonMatch = text.match(/"positive":\s*"([^"]*)"/);
            const negativeJsonMatch = text.match(/"negative":\s*"([^"]*)"/);

            if (positiveJsonMatch) {
                positivePrompt.value = cleanText(positiveJsonMatch[1].trim());
                hasAnyValidData = true;
            }
            if (negativeJsonMatch) {
                negativePrompt.value = cleanText(negativeJsonMatch[1].trim());
                hasAnyValidData = true;
            }
        }

        // 解析生成参数
        const params = {
            steps: text.match(/Steps:\s*(\d+)/)?.[1],
            sampler: text.match(/Sampler:\s*([^,]+)/)?.[1],
            cfgScale: text.match(/CFG scale:\s*(\d+(?:\.\d+)?)/)?.[1],
            seed: text.match(/Seed:\s*(\d+)/)?.[1],
            size: text.match(/Size:\s*([^,]+)/)?.[1],
            modelHash: text.match(/Model hash:\s*([^,]+)/)?.[1],
            model: text.match(/Model:\s*([^,]+)/)?.[1],
            denoisingStrength: text.match(/Denoising strength:\s*(\d+(?:\.\d+)?)/)?.[1],
            clipSkip: text.match(/Clip skip:\s*(\d+)/)?.[1],
            hiresUpscale: text.match(/Hires upscale:\s*(\d+(?:\.\d+)?)/)?.[1],
            hiresSteps: text.match(/Hires steps:\s*(\d+)/)?.[1],
            hiresUpscaler: text.match(/Hires upscaler:\s*([^,]+)/)?.[1],
            loraHashes: text.match(/Lora hashes:\s*"([^"]+)"/)?.[1]?.split(', ') || [],
            version: text.match(/Version:\s*([^,\n]+)/)?.[1]
        };

        // 检查是否有任何有效的生成参数
        const hasAnyParams = Object.values(params).some(v => v != null && v !== '');
        if (hasAnyParams) {
            generationParams.value = params;
            hasAnyValidData = true;
        }

        // 解析所有 LoRA 信息
        const loras = parseAllLoraInfo(text);
        if (loras.length > 0) {
            console.log('Successfully parsed LoRAs:', loras);
            generationParams.value.loras = loras;
            hasAnyValidData = true;
        } else {
            console.log('No LoRAs found in image metadata');
            // 打印一段原始文本用于调试
            console.log('Sample of image metadata:', text.substring(0, 1000));
        }

        if (!hasAnyValidData) {
            errorMessage.value = '无法解析图片中的提示信息';
        }
    } catch (error) {
        console.error('Error parsing image:', error);
        errorMessage.value = '解析图片失败';
    }
}

async function copyPositivePrompt() {
    try {
        // 复制前再次清理文本
        const cleanedText = cleanText(positivePrompt.value);
        await navigator.clipboard.writeText(cleanedText);
        showPositiveCopySuccess.value = true;
        setTimeout(() => {
            showPositiveCopySuccess.value = false;
        }, 2000);
    } catch (err) {
        console.error('复制失败:', err);
        // 添加备用复制方法
        fallbackCopy(cleanText(positivePrompt.value));
    }
}

async function copyNegativePrompt() {
    try {
        // 复制前再次清理文本
        const cleanedText = cleanText(negativePrompt.value);
        await navigator.clipboard.writeText(cleanedText);
        showNegativeCopySuccess.value = true;
        setTimeout(() => {
            showNegativeCopySuccess.value = false;
        }, 2000);
    } catch (err) {
        console.error('复制失败:', err);
        // 添加备用复制方法
        fallbackCopy(cleanText(negativePrompt.value));
    }
}

// 添加备用复制方法
function fallbackCopy(text) {
    // 使用清理后的文本
    const cleanedText = cleanText(text);
    // 创建临时文本区域
    const textArea = document.createElement('textarea');
    textArea.value = cleanedText;
    document.body.appendChild(textArea);
    
    // 选择并复制文本
    textArea.select();
    try {
        document.execCommand('copy');
        // 显示成功提示
        if (text === positivePrompt.value) {
            showPositiveCopySuccess.value = true;
            setTimeout(() => showPositiveCopySuccess.value = false, 2000);
        } else {
            showNegativeCopySuccess.value = true;
            setTimeout(() => showNegativeCopySuccess.value = false, 2000);
        }
    } catch (err) {
        console.error('Fallback copy failed:', err);
        alert('复制失败，请手动复制');
    }
    
    // 清理临时元素
    document.body.removeChild(textArea);
}

// 修改 handleLoraClick 函数以支持两种格式
function handleLoraClick(lora) {
    const searchName = lora.name;
    console.log('Searching for LoRA:', searchName);
    
    const results = findLorasByName(searchName);
    if (results.length === 0) {
        alert('未找到相关 LoRA');
    } else if (results.length === 1) {
        globalState.openLoraDetail(results[0]);
    } else {
        globalState.openSearchResults(results, searchName);
    }
}

function handleClose() {
    emit('close-image-detail');
}

function handleOverlayClick(e) {
    if (e.target.classList.contains('image-overlay')) {
        emit('close-image-detail');
    }
}
</script>

<template>
    <Transition name="fade">
        <div v-if="show" class="overlay image-overlay" @click="handleOverlayClick">
            <div class="detail-card" @click.stop>
                <button class="close-btn" @click="handleClose">×</button>
                <div class="content-wrapper">
                    <div v-if="errorMessage" class="error-message">{{ errorMessage }}</div>
                    <div v-else>
                        <div class="prompts-container">
                            <div v-if="positivePrompt" class="prompt-section">
                                <h2>Positive Prompt</h2>
                                <div class="prompt-container">
                                    <div class="prompt-box">{{ positivePrompt }}</div>
                                    <button class="copy-btn" 
                                            :class="{ 'success': showPositiveCopySuccess }" 
                                            @click.stop="copyPositivePrompt">
                                        {{ showPositiveCopySuccess ? '已复制!' : '复制' }}
                                    </button>
                                </div>
                            </div>
                            <div v-if="negativePrompt" class="prompt-section">
                                <h2>Negative Prompt</h2>
                                <div class="prompt-container">
                                    <div class="prompt-box">{{ negativePrompt }}</div>
                                    <button class="copy-btn" 
                                            :class="{ 'success': showNegativeCopySuccess }" 
                                            @click.stop="copyNegativePrompt">
                                        {{ showNegativeCopySuccess ? '已复制!' : '复制' }}
                                    </button>
                                </div>
                            </div>
                        </div>

                        <!-- 生成参数展示 -->
                        <div v-if="Object.values(generationParams).some(v => v)" class="params-section">
                            <h2>Generation Parameters</h2>
                            <div class="params-grid">
                                <div v-if="generationParams.steps" class="param-item">
                                    <span class="param-label">Steps</span>
                                    <span class="param-value">{{ generationParams.steps }}</span>
                                </div>
                                <div v-if="generationParams.sampler" class="param-item">
                                    <span class="param-label">Sampler</span>
                                    <span class="param-value">{{ generationParams.sampler }}</span>
                                </div>
                                <div v-if="generationParams.cfgScale" class="param-item">
                                    <span class="param-label">CFG Scale</span>
                                    <span class="param-value">{{ generationParams.cfgScale }}</span>
                                </div>
                                <div v-if="generationParams.seed" class="param-item">
                                    <span class="param-label">Seed</span>
                                    <span class="param-value">{{ generationParams.seed }}</span>
                                </div>
                                <div v-if="generationParams.size" class="param-item">
                                    <span class="param-label">Size</span>
                                    <span class="param-value">{{ generationParams.size }}</span>
                                </div>
                                <div v-if="generationParams.model" class="param-item">
                                    <span class="param-label">Model</span>
                                    <span class="param-value">{{ generationParams.model }}</span>
                                </div>
                                <!-- 其他参数... -->
                            </div>
                        </div>

                        <!-- 统一的 LoRA 展示部分 -->
                        <div v-if="generationParams.loras?.length" class="lora-section">
                            <h3>使用的 LoRA</h3>
                            <div class="lora-list">
                                <div v-for="lora in generationParams.loras" 
                                     :key="lora.name"
                                     class="lora-item"
                                     @click="handleLoraClick(lora)">
                                    <span class="lora-name">{{ lora.name }}</span>
                                    <span class="lora-weight">× {{ lora.weight }}</span>
                                    <span v-if="lora.hash" class="lora-hash" :title="lora.hash">
                                        #{{ lora.hash.substring(0, 8) }}
                                    </span>
                                    <span class="lora-source" :title="lora.source === 'comfyui' ? 'ComfyUI' : 'WebUI'">
                                        {{ lora.source === 'comfyui' ? '🔧' : '🌐' }}
                                    </span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </Transition>
</template>

<style scoped>
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

.content-wrapper {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.prompt-section {
    margin-bottom: 1.5rem;
}

.prompt-container {
    display: flex;
    align-items: center;
    gap: 1rem;
}

.prompt-box {
    flex: 1;
    padding: 1rem;
    border: 1px solid #ddd;
    border-radius: 8px;
    background: #f8f9fa;
    font-size: 1rem;
    white-space: pre-wrap;
    word-break: break-word;
}

.copy-btn {
    padding: 0.5rem 1rem;
    border-radius: 4px;
    border: 1px solid #e0e0e0;
    background: white;
    color: #666;
    font-size: 0.9rem;
    cursor: pointer;
    transition: all 0.3s ease;
}

.copy-btn:hover {
    background: #f5f5f5;
    border-color: #ccc;
}

.copy-btn.success {
    background: #4caf50;
    color: white;
    border-color: #4caf50;
    transition: all 0.2s ease;
}

copy-btn:hover.success {
    background: #45a049;
}

.error-message {
    color: #dc3545;
    padding: 1rem;
    background: #fee;
    border-radius: 8px;
    text-align: center;
}

.params-section {
    margin-top: 2rem;
    padding: 1.5rem;
    background: #f8f9fa;
    border-radius: 12px;
    box-shadow: 0 2px 4px rgba(0,0,0,0.05);
}

.params-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 1rem;
    margin-top: 1rem;
}

.param-item {
    padding: 1rem;
    background: white;
    border-radius: 8px;
    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
}

.param-label {
    display: block;
    color: #666;
    font-size: 0.9rem;
    margin-bottom: 0.5rem;
}

.param-value {
    font-size: 1rem;
    color: #2196f3;
    font-weight: 500;
}

.lora-hashes {
    margin-top: 1.5rem;
    padding-top: 1.5rem;
    border-top: 1px solid #eee;
}

.hash-list {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    margin-top: 0.5rem;
}

.hash-item {
    background: #e3f2fd;
    color: #1976d2;
    padding: 0.5rem 1rem;
    border-radius: 4px;
    font-size: 0.9rem;
    box-shadow: 0 1px 2px rgba(0,0,0,0.1);
    border: none;
    cursor: pointer;
    transition: all 0.3s ease;
}

.hash-item:hover {
    background: #bbdefb;
    transform: translateY(-1px);
    box-shadow: 0 2px 4px rgba(0,0,0,0.15);
}

.prompts-container {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
}

.lora-section {
    margin-top: 1.5rem;
    padding: 1rem;
    background: #f8f9fa;
    border-radius: 8px;
}

.lora-list {
    display: flex;
    flex-wrap: wrap;
    gap: 0.8rem;
    margin-top: 0.5rem;
}

.lora-item {
    background: #e3f2fd;
    padding: 0.5rem 1rem;
    border-radius: 4px;
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.9rem;
    cursor: pointer;
    transition: all 0.3s ease;
}

.lora-item:hover {
    transform: translateY(-2px);
    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    background: #bbdefb;
}

.lora-name {
    color: #1976d2;
    font-weight: 500;
}

.lora-weight {
    color: #666;
    font-family: monospace;
    padding: 0.1rem 0.3rem;
    background: rgba(0, 0, 0, 0.05);
    border-radius: 3px;
}

.lora-hash {
    color: #666;
    font-family: monospace;
    font-size: 0.8rem;
}

.lora-source {
    font-size: 1rem;
    opacity: 0.7;
    margin-left: auto;
}

h2 {
    color: #333;
    font-size: 1.25rem;
    margin-bottom: 1rem;
    font-weight: 600;
}

h3 {
    color: #444;
    font-size: 1.1rem;
    margin-bottom: 0.75rem;
}
</style>
