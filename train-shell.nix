{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:

let
  pythonEnv = pkgs.python312;

  basePackages = [
    pythonEnv
    pkgs.git
    pkgs.gcc
    pkgs.glibc
    pkgs.glibc.dev
    pkgs.cmake
    pkgs.binutils
    pkgs.zlib
    pkgs.zlib.dev
    pkgs.stdenv.cc.cc.lib
    pkgs.gnumake
    pkgs.gcc-unwrapped.lib
  ];

  hooks = {
    shellHook = ''
      echo "Initialisiere Python-Umgebung..."

      # Set critical environment variables
      export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.glibc}/lib:${pkgs.zlib}/lib:$LD_LIBRARY_PATH
      export CPATH=${pkgs.glibc.dev}/include:${pkgs.gcc}/include:${pkgs.zlib.dev}/include:$CPATH
      export LIBRARY_PATH=${pkgs.glibc}/lib:${pkgs.gcc.cc.lib}/lib:${pkgs.zlib}/lib:$LIBRARY_PATH

      # Remove old virtual environment
      rm -rf .venv

      # Create new virtual environment
      ${pythonEnv}/bin/python -m venv .venv
      source .venv/bin/activate

      echo "Installing Python packages..."

      pip install --upgrade pip
      pip install wheel setuptools

      echo "Installing PyTorch..."
      pip install torch --index-url https://download.pytorch.org/whl/cpu

      echo "Installing NumPy..."
      pip install numpy==1.26.3

      echo "Installing other ML packages..."
      pip install \
          pandas==2.2.0 \
          transformers==4.36.2 \
          datasets==2.18.0 \
          accelerate==0.27.0 \
          huggingface-hub==0.20.3 \
          PyGithub==2.1.1 \
          peft==0.9.0 \
          PyYAML==6.0.1 \
          tqdm==4.66.1 \
          psutil==5.9.8 \
          requests==2.31.0 \
          inquirer==3.1.3 \
          lime==0.2.0.1 \
          streamlit \
          plotly \
          wordcloud==1.9.3 \
          networkx==3.2.1 \
          matplotlib==3.8.2 \
          seaborn==0.13.2

      # Install llama-cpp-python (CPU-only) with proper headers
      echo "Installing llama-cpp-python..."
      export CPLUS_INCLUDE_PATH=${pkgs.gcc-unwrapped.lib}/include/c++/${pkgs.gcc-unwrapped.version}:${pkgs.glibc.dev}/include
      FORCE_CMAKE=1 \
      pip install llama-cpp-python==0.2.56 --no-cache-dir --force-reinstall --verbose

      # Install compatible SHAP version
      echo "Installing SHAP..."
      pip install shap==0.45.1 --no-cache-dir

      echo "Verifying installation..."
      if python -c "import torch; import transformers; import peft; import shap; import numpy; print('✓ All packages installed successfully!')" ; then
          echo "✓ Installation successful!"
      else
          echo "✗ Installation failed!"
          exit 1
      fi

      # CPU-specific optimizations
      export OMP_NUM_THREADS=$(nproc)
      # CUDA Support
      if [ -d "${pkgs.cudatoolkit}/lib" ]; then
        export LD_LIBRARY_PATH="${pkgs.cudatoolkit}/lib:$LD_LIBRARY_PATH"
        export CUDA_HOME="${pkgs.cudatoolkit}"
      fi
      echo "NixOS AI Training Environment activated!"
      echo "----------------------------------------"
      echo "Python Version: $(python --version)"
      echo "NumPy Version: $(python -c 'import numpy; print(numpy.__version__)')"
      echo "Torch Version: $(python -c 'import torch; print(torch.__version__)')"
      echo "CUDA Available: $(python -c 'import torch; print(torch.cuda.is_available())')"
      echo "----------------------------------------"
    '';
  };

in
pkgs.mkShell {
  name = "NixOsControlCenter-AI-Training-Shell";
  buildInputs = basePackages;
  inherit (hooks) shellHook;
}
