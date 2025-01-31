from flask import Flask, jsonify, request, send_file
from flask_cors import CORS
import logging
import subprocess
import sys
import os
import json
import re
from safetensors import safe_open
import uuid
import time
import base64

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

CONFIG_PATH = os.path.join(os.path.dirname(
    os.path.abspath(__file__)), 'config.json')

CLICKS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'clicks.json')

LORA_COMBINE_PATH = None

def ensure_combine_path():
    global LORA_COMBINE_PATH
    config = load_config()
    base_path = config.get('lora_path', '')
    LORA_COMBINE_PATH = os.path.join(base_path, 'LoraCombine')
    if not os.path.exists(LORA_COMBINE_PATH):
        os.makedirs(LORA_COMBINE_PATH)

def load_config():
    try:
        if os.path.exists(CONFIG_PATH):
            with open(CONFIG_PATH, 'r') as f:
                return json.load(f)
        return {"lora_path": ""}
    except Exception as e:
        logger.error(f"Error loading config: {e}")
        return {"lora_path": ""}

def load_clicks():
    try:
        if os.path.exists(CLICKS_PATH):
            with open(CLICKS_PATH, 'r', encoding='utf-8') as f:
                data = json.load(f)
                # 如果是旧格式，转换为新格式
                if not isinstance(data, dict) or ('global' not in data and 'search' not in data):
                    # 将旧数据迁移到新格式
                    new_data = {
                        "global": data if isinstance(data, dict) else {},
                        "search": {}
                    }
                    # 保存新格式
                    save_clicks(new_data)
                    return new_data
                return data
        return {"global": {}, "search": {}}
    except Exception as e:
        logger.error(f"Error loading clicks: {e}")
        return {"global": {}, "search": {}}

def save_config(config):
    with open(CONFIG_PATH, 'w') as f:
        json.dump(config, f, indent=4)

def save_clicks(clicks):
    with open(CLICKS_PATH, 'w', encoding='utf-8') as f:
        json.dump(clicks, f, indent=4, ensure_ascii=False)

@app.route('/config', methods=['GET'])
def get_config():
    return jsonify(load_config())

@app.route('/config', methods=['POST'])
def update_config():
    try:
        config = load_config()
        new_config = request.json
        config.update(new_config)
        save_config(config)
        return jsonify({"status": "success"})
    except Exception as e:
        logger.error(f"Error updating config: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/select-folder', methods=['GET'])
def select_folder():
    try:
        # 获取当前脚本所在目录
        current_dir = os.path.dirname(os.path.abspath(__file__))
        dialog_script = os.path.join(current_dir, 'folder_dialog.py')

        # 调用对话框脚本并获取输出
        result = subprocess.run([sys.executable, dialog_script],
                                capture_output=True,
                                text=True)

        folder_path = result.stdout.strip()
        logger.info(f"Selected folder: {folder_path}")

        return jsonify({'path': folder_path})
    except Exception as e:
        logger.error(f"Error selecting folder: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/folders', methods=['GET'])
def get_folders():
    try:
        config = load_config()
        base_path = config.get('lora_path', '')
        sub_path = request.args.get('path', '')

        if not base_path or not os.path.exists(base_path):
            return jsonify({'error': 'Invalid base path'}), 404

        current_path = os.path.join(base_path, sub_path)
        if not os.path.exists(current_path):
            return jsonify({'error': 'Path not found'}), 404

        # 确保不会访问基础路径以外的目录
        if not os.path.realpath(current_path).startswith(os.path.realpath(base_path)):
            return jsonify({'error': 'Invalid path'}), 403

        folders = [d for d in os.listdir(current_path)
                   if os.path.isdir(os.path.join(current_path, d))]

        return jsonify({
            'folders': folders,
            'current_path': sub_path or '/',
            'can_go_back': bool(sub_path)
        })
    except Exception as e:
        logger.error(f"Error scanning folders: {e}")
        return jsonify({'error': str(e)}), 500

def get_lora_metadata(file_path):
    try:
        with safe_open(file_path, framework="pt") as f:
            metadata = f.metadata()
            return {
                'ss_base_model_version': metadata.get('ss_base_model_version', 'Unknown'),
                'ss_network_module': metadata.get('ss_network_module', ''),
                'ss_network_dim': metadata.get('ss_network_dim', ''),
                'ss_network_alpha': metadata.get('ss_network_alpha', '')
            }
    except Exception as e:
        logger.error(f"Error reading safetensors metadata: {e}")
        return {}

def get_lora_config(file_path):
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
            return {
                'activation_text': config.get('activation text', ''),
                'preferred_weight': config.get('preferred weight', 0),
                'notes': config.get('notes', ''),
                'description': config.get('description', '')
            }
    except Exception as e:
        logger.error(f"Error reading lora config: {e}")
        return {}

@app.route('/lora-files', methods=['GET'])
def get_lora_files():
    try:
        config = load_config()
        base_path = config.get('lora_path', '')
        sub_path = request.args.get('path', '').strip('/')  # 修改这里

        if not base_path or not os.path.exists(base_path):
            return jsonify({'error': 'Invalid base path'}), 404

        current_path = os.path.normpath(os.path.join(base_path, sub_path))
        if not os.path.exists(current_path):
            return jsonify({'error': 'Path not found'}), 404

        if not os.path.realpath(current_path).startswith(os.path.realpath(base_path)):
            return jsonify({'error': 'Invalid path'}), 403

        lora_files = []
        files = os.listdir(current_path)

        for file in files:
            if file.endswith('.safetensors'):
                base_name = file[:-11]
                full_path = os.path.join(current_path, file)

                metadata = get_lora_metadata(full_path)

                # 检查相关文件
                preview_file = next((f for f in files if f.startswith(
                    base_name) and f.endswith('.png')), None)
                config_file = next((f for f in files if f.startswith(
                    base_name) and f.endswith('.json')), None)

                # 获取或创建空的配置数据
                config_data = {}
                if config_file:
                    config_path = os.path.join(current_path, config_file)
                    config_data = get_lora_config(config_path)

                lora_info = {
                    'name': file,
                    'base_name': base_name,
                    'has_preview': bool(preview_file),
                    'has_config': bool(config_file),
                    'preview_path': f'/preview?path={sub_path}&file={preview_file}' if preview_file else None,
                    'metadata': metadata,
                    'config': config_data  # 即使没有配置文件也返回空对象
                }
                lora_info = add_click_count_to_lora_info(lora_info)
                lora_files.append(lora_info)

        return jsonify({
            'lora_files': lora_files,
            'current_path': sub_path or '/'
        })

    except Exception as e:
        logger.error(f"Error scanning lora files: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/preview', methods=['GET'])
def get_preview():
    try:
        config = load_config()
        base_path = config.get('lora_path', '')
        sub_path = request.args.get('path', '')
        file_name = request.args.get('file', '')

        if not all([base_path, file_name]):
            return jsonify({'error': 'Invalid parameters'}), 400

        file_path = os.path.join(base_path, sub_path, file_name)

        if not os.path.exists(file_path):
            return jsonify({'error': 'File not found'}), 404

        return send_file(file_path, mimetype='image/png')

    except Exception as e:
        logger.error(f"Error sending preview: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/previews', methods=['GET'])
def get_previews():
    try:
        config = load_config()
        base_path = config.get('lora_path', '')
        lora_name = request.args.get('name', '')
        if lora_name.endswith('.'):
            lora_name = lora_name[:-1]
        sub_path = request.args.get('path', '')

        if not all([base_path, lora_name]):
            return jsonify({'error': 'Invalid parameters'}), 400

        current_path = os.path.join(base_path, sub_path) if sub_path else base_path
        
        # 获取当前目录下所有文件
        files = os.listdir(current_path)
        
        # 找出所有匹配的预览图
        preview_pattern = re.compile(f'^{re.escape(lora_name)}(_\\d+)?\\.png$')
        previews = [f'/preview?path={sub_path}&file={f}' for f in files if preview_pattern.match(f)]
        
        return jsonify({'previews': sorted(previews)})

    except Exception as e:
        logger.error(f"Error getting previews: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/upload-preview', methods=['POST'])
def upload_preview():
    try:
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400

        file = request.files['file']
        lora_name = request.form.get('lora_name')
        # 如果最后是.则去掉
        if lora_name.endswith('.'):
            lora_name = lora_name[:-1]
        sub_path = request.form.get('path', '').strip('/')

        if not file or not lora_name:
            return jsonify({'error': 'Invalid parameters'}), 400

        config = load_config()
        base_path = config.get('lora_path', '')
        
        # 构造完整的目标目录路径
        current_path = os.path.join(base_path, sub_path) if sub_path else base_path
        
        # 确保目标目录存在且在base_path下
        if not os.path.exists(current_path):
            return jsonify({'error': 'Target directory not found'}), 404
            
        if not os.path.realpath(current_path).startswith(os.path.realpath(base_path)):
            return jsonify({'error': 'Invalid path'}), 403

        # 获取当前目录下所有预览图数量并找到最大编号
        files = os.listdir(current_path)
        preview_pattern = re.compile(f'^{re.escape(lora_name)}(_\\d+)?\\.png$')
        existing_previews = [f for f in files if preview_pattern.match(f)]
        
        # 确定新文件名
        if existing_previews:
            max_number = max([int(re.search(r'_(\d+)\.png$', f).group(1)) for f in existing_previews if re.search(r'_(\d+)\.png$', f)] or [0])
            next_number = max_number + 1
            new_filename = f'{lora_name}_{next_number}.png'
        else:
            new_filename = f'{lora_name}.png'

        file_path = os.path.join(current_path, new_filename)
        
        logger.info(f"Saving preview to: {file_path}")
        file.save(file_path)

        return jsonify({
            'status': 'success',
            'filename': new_filename,
            'path': sub_path
        })

    except Exception as e:
        logger.error(f"Error uploading preview: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/update-config', methods=['POST'])
def update_lora_config():
    try:
        data = request.json
        base_path = load_config().get('lora_path', '')
        sub_path = data.get('path', '').strip('/')
        lora_name = data.get('lora_name', '')
        if lora_name.endswith('.'):
            lora_name = lora_name[:-1]
        config = data.get('config', {})

        if not all([base_path, lora_name]):
            return jsonify({'error': 'Invalid parameters'}), 400

        # 构建配置文件路径
        current_path = os.path.join(base_path, sub_path) if sub_path else base_path
        config_filename = f"{lora_name}.json"
        config_path = os.path.join(current_path, config_filename)

        # 准备新的配置数据
        config_data = {
            'description': config.get('description', ''),
            'sd version': 'SDXL',  # 添加默认的SD版本信息
            'activation text': config.get('activation_text', ''),
            'preferred weight': config.get('preferred_weight', 0),
            'notes': config.get('notes', '')
        }

        # 如果目录不存在则创建
        os.makedirs(os.path.dirname(config_path), exist_ok=True)

        # 写入文件
        with open(config_path, 'w', encoding='utf-8') as f:
            json.dump(config_data, f, indent=4, ensure_ascii=False)

        return jsonify({
            'status': 'success',
            'has_config': True  # 返回更新后的状态
        })

    except Exception as e:
        logger.error(f"Error updating lora config: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/swap-preview', methods=['POST'])
def swap_preview():
    try:
        data = request.json
        base_path = load_config().get('lora_path', '')
        sub_path = data.get('path', '').strip('/')
        lora_name = data.get('lora_name', '')
        if lora_name.endswith('.'):
            lora_name = lora_name[:-1]
        preview_index = data.get('preview_index', 0)

        logger.info(f"Swapping preview - Path: {sub_path}, Lora: {lora_name}, Index: {preview_index}")

        if not all([base_path, lora_name]):
            return jsonify({'error': 'Invalid parameters'}), 400

        current_path = os.path.join(base_path, sub_path) if sub_path else base_path
        
        if not os.path.exists(current_path):
            logger.error(f"Directory not found: {current_path}")
            return jsonify({'error': 'Directory not found'}), 404

        # 获取所有预览图
        files = os.listdir(current_path)
        preview_pattern = re.compile(f'^{re.escape(lora_name)}(\\.png|_\\d+\\.png)$')
        preview_files = [f for f in files if preview_pattern.match(f)]
        
        # 自定义排序函数
        def sort_preview_files(filename):
            if filename == f"{lora_name}.png":  # 主预览图
                return -1
            match = re.search(r'_(\d+)\.png$', filename)
            return int(match.group(1)) if match else 0

        preview_files = sorted(preview_files, key=sort_preview_files)
        logger.info(f"Found and sorted preview files: {preview_files}")
        
        if not preview_files:
            return jsonify({'error': 'No preview files found'}), 404
        
        if preview_index >= len(preview_files):
            logger.error(f"Invalid preview index: {preview_index}, total files: {len(preview_files)}")
            return jsonify({'error': f'Invalid preview index: {preview_index}'}), 400

        # 获取主预览图和目标预览图的路径
        main_preview = preview_files[0]
        target_preview = preview_files[preview_index]
        
        logger.info(f"Swapping {main_preview} with {target_preview}")
        
        if main_preview == target_preview:
            return jsonify({'status': 'success', 'message': 'Same file, no swap needed'})
        
        main_preview_path = os.path.join(current_path, main_preview)
        target_preview_path = os.path.join(current_path, target_preview)
        temp_preview_path = os.path.join(current_path, f'{lora_name}_temp.png')
        
        # 执行文件交换
        os.rename(main_preview_path, temp_preview_path)
        os.rename(target_preview_path, main_preview_path)
        os.rename(temp_preview_path, target_preview_path)

        return jsonify({'status': 'success'})

    except Exception as e:
        logger.error(f"Error swapping preview: {e}")
        return jsonify({'error': str(e)}), 500

def normalize_search_term(term):
    """规范化搜索词格式"""
    if not term:
        return ''
    return re.sub(r'[\s-]+', '_', term.lower().strip())

@app.route('/scan-all-loras', methods=['GET'])
def scan_all_loras():
    try:
        config = load_config()
        base_path = config.get('lora_path', '')

        if not base_path or not os.path.exists(base_path):
            return jsonify({'error': 'Invalid base path'}), 404

        all_lora_files = []
        search_term = normalize_search_term(request.args.get('search_term'))  # 添加搜索词参数

        def scan_directory(directory, relative_path=''):
            try:
                for item in os.listdir(directory):
                    full_path = os.path.join(directory, item)
                    item_relative_path = os.path.join(relative_path, item)

                    if os.path.isdir(full_path):
                        # 递归扫描子目录
                        scan_directory(full_path, item_relative_path)
                    elif item.endswith('.safetensors'):
                        # 处理 LoRA 文件
                        base_name = item[:-11]
                        metadata = get_lora_metadata(full_path)

                        # 检查相关文件
                        preview_file = next((f for f in os.listdir(directory) if f.startswith(base_name) and f.endswith('.png')), None)
                        config_file = next((f for f in os.listdir(directory) if f.startswith(base_name) and f.endswith('.json')), None)

                        # 获取配置数据
                        config_data = {}
                        if config_file:
                            config_path = os.path.join(directory, config_file)
                            config_data = get_lora_config(config_path)

                        lora_info = {
                            'name': item,
                            'base_name': base_name,
                            'has_preview': bool(preview_file),
                            'has_config': bool(config_file),
                            'preview_path': f'/preview?path={relative_path}&file={preview_file}' if preview_file else None,
                            'metadata': metadata,
                            'config': config_data,
                            'relative_path': relative_path  # 添加相对路径信息
                        }
                        lora_info = add_click_count_to_lora_info(lora_info, search_term)
                        all_lora_files.append(lora_info)
            except Exception as e:
                logger.error(f"Error scanning directory {directory}: {e}")

        # 开始递归扫描
        scan_directory(base_path)
        
        return jsonify({
            'lora_files': all_lora_files
        })

    except Exception as e:
        logger.error(f"Error scanning all lora files: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/lora-click', methods=['POST'])  # 修正这里，使用列表而不是字典索引
def record_lora_click():
    try:
        data = request.json
        lora_name = data.get('lora_name')
        search_term = normalize_search_term(data.get('search_term'))  # 新增搜索词参数
        
        if not lora_name:
            return jsonify({'error': 'Missing lora_name'}), 400

        clicks = load_clicks()
        
        # 更新全局点击量
        clicks["global"][lora_name] = clicks["global"].get(lora_name, 0) + 1
        
        # 如果有搜索词，更新搜索相关点击量
        if search_term:
            if search_term not in clicks["search"]:
                clicks["search"][search_term] = {}
            clicks["search"][search_term][lora_name] = \
                clicks["search"][search_term].get(lora_name, 0) + 1
        
        save_clicks(clicks)

        return jsonify({
            'status': 'success',
            'global_clicks': clicks["global"][lora_name],
            'search_clicks': clicks["search"].get(search_term, {}).get(lora_name, 0) if search_term else 0
        })
    except Exception as e:
        logger.error(f"Error recording click: {e}")
        return jsonify({'error': str(e)}), 500

def add_click_count_to_lora_info(lora_info, search_term=None):
    try:
        clicks = load_clicks()
        normalized_term = normalize_search_term(search_term) if search_term else None
        
        # 添加全局点击数
        lora_info['global_clicks'] = clicks["global"].get(lora_info['name'], 0)
        
        # 添加搜索相关点击数
        if normalized_term:
            print(f"Adding search clicks for {lora_info['name']} with term {normalized_term}")
            print(f"Search clicks data: {clicks['search'].get(normalized_term, {})}")
            lora_info['search_clicks'] = clicks["search"].get(normalized_term, {}).get(lora_info['name'], 0)
        else:
            lora_info['search_clicks'] = 0
            
        print(f"Clicks for {lora_info['name']}: global={lora_info['global_clicks']}, search={lora_info['search_clicks']}")
        return lora_info
    except Exception as e:
        logger.error(f"Error adding click count: {e}")
        lora_info['global_clicks'] = 0
        lora_info['search_clicks'] = 0
        return lora_info

@app.route('/lora-combinations', methods=['GET'])
def get_combinations():
    ensure_combine_path()
    combinations = []
    # 遍历LoraCombine目录下的所有文件夹
    for dirname in os.listdir(LORA_COMBINE_PATH):
        dir_path = os.path.join(LORA_COMBINE_PATH, dirname)
        if os.path.isdir(dir_path):
            json_path = os.path.join(dir_path, 'config.json')
            if os.path.exists(json_path):
                with open(json_path, 'r', encoding='utf-8') as f:
                    combo = json.load(f)
                    # 添加预览图信息
                    previews = [f for f in os.listdir(dir_path) if f.endswith('.png')]
                    if previews:
                        combo['preview_path'] = f'/combination-preview/{dirname}/{previews[0]}'
                    combinations.append(combo)
    return jsonify(combinations)

@app.route('/lora-combinations', methods=['POST'])
def create_combination():
    ensure_combine_path()
    data = request.json
    
    # 生成唯一ID作为文件夹名
    combo_id = str(uuid.uuid4())
    combo_dir = os.path.join(LORA_COMBINE_PATH, combo_id)
    os.makedirs(combo_dir, exist_ok=True)
    
    # 保存配置信息
    data['id'] = combo_id
    data['created_at'] = int(time.time())
    with open(os.path.join(combo_dir, 'config.json'), 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    return jsonify(data)

@app.route('/combination-preview/<combo_id>/<filename>', methods=['GET'])
def get_combination_preview(combo_id, filename):
    try:
        preview_path = os.path.join(LORA_COMBINE_PATH, combo_id, filename)
        return send_file(preview_path, mimetype='image/png')
    except Exception as e:
        logger.error(f"Error sending combination preview: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/combination-preview/<combo_id>', methods=['POST'])
def upload_combination_preview(combo_id):
    try:
        if 'file' not in request.files:
            return jsonify({'error': 'No file provided'}), 400

        file = request.files['file']
        combo_dir = os.path.join(LORA_COMBINE_PATH, combo_id)
        
        if not os.path.exists(combo_dir):
            return jsonify({'error': 'Combination not found'}), 404

        # 获取现有预览图数量
        previews = [f for f in os.listdir(combo_dir) if f.endswith('.png')]
        if previews:
            next_num = max([int(re.search(r'_(\d+)\.png$', f).group(1)) 
                          for f in previews if re.search(r'_(\d+)\.png$', f)] or [0]) + 1
            filename = f'preview_{next_num}.png'
        else:
            filename = 'preview.png'
        
        file_path = os.path.join(combo_dir, filename)
        file.save(file_path)
        
        return jsonify({
            'status': 'success',
            'preview_path': f'/combination-preview/{combo_id}/{filename}'
        })
    except Exception as e:
        logger.error(f"Error uploading combination preview: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/combination-previews/<combo_id>', methods=['GET'])
def get_combination_previews(combo_id):
    try:
        combo_dir = os.path.join(LORA_COMBINE_PATH, combo_id)
        if not os.path.exists(combo_dir):
            return jsonify({'error': 'Combination not found'}), 404
            
        previews = sorted([f'/combination-preview/{combo_id}/{f}' 
                        for f in os.listdir(combo_dir) 
                        if f.endswith('.png')],
                        key=lambda x: 'preview.png' in x)
        
        return jsonify({'previews': previews})
    except Exception as e:
        logger.error(f"Error getting combination previews: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/combination-preview/<combo_id>/<filename>', methods=['DELETE'])
def delete_combination_preview(combo_id, filename):
    try:
        preview_path = os.path.join(LORA_COMBINE_PATH, combo_id, filename)
        if not os.path.exists(preview_path):
            return jsonify({'error': 'Preview not found'}), 404
            
        # 不允许删除最后一张预览图
        combo_dir = os.path.join(LORA_COMBINE_PATH, combo_id)
        previews = [f for f in os.listdir(combo_dir) if f.endswith('.png')]
        if len(previews) <= 1:
            return jsonify({'error': 'Cannot delete the last preview'}), 400
            
        # 删除文件
        os.remove(preview_path)
        
        return jsonify({'status': 'success'})
    except Exception as e:
        logger.error(f"Error deleting combination preview: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/lora-combinations/<combo_id>', methods=['DELETE'])
def delete_combination(combo_id):
    try:
        combo_dir = os.path.join(LORA_COMBINE_PATH, combo_id)
        if not os.path.exists(combo_dir):
            return jsonify({'error': 'Combination not found'}), 404
            
        # 删除目录及其所有内容
        import shutil
        shutil.rmtree(combo_dir)
        
        return jsonify({'status': 'success'})
    except Exception as e:
        logger.error(f"Error deleting combination: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    try:
        logger.info("Starting Flask server...")        
        app.run(debug=True, port=5000)    
    except Exception as e:        
        logger.error(f"Server error: {e}")
        input("Press Enter to exit...")
