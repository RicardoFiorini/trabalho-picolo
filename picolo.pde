import java.util.ArrayList;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import javax.swing.JFileChooser;
import javax.swing.filechooser.FileNameExtensionFilter;

// Classe principal para gerenciar o processo de imagens
PImage[] images;
ImageProcessor processor = new ImageProcessor();

void setup() {
    size(1200, 900);
    noLoop();

    images = selectImages(); // Chama a função de seleção de imagens

    // Validação de entrada
    if (images == null || images.length == 0) {
        println("Erro ao carregar imagens ou nenhuma imagem selecionada.");
        return;
    }

    processor.processImages(images);
    displayAnalysis(); // Mostrar análise após processamento
}

void draw() {
    displayImages(images);
}

PImage[] selectImages() {
    JFileChooser chooser = new JFileChooser();
    chooser.setMultiSelectionEnabled(true);
    FileNameExtensionFilter filter = new FileNameExtensionFilter("Image Files", "jpg", "png", "bmp", "jpeg");
    chooser.setFileFilter(filter);
    int returnVal = chooser.showOpenDialog(null);
    if(returnVal == JFileChooser.APPROVE_OPTION) {
        return (PImage[]) stream(chooser.getSelectedFiles()).map(f -> loadImage(f.getAbsolutePath())).toArray(PImage[]::new);
    }
    return null;
}

void displayImages(PImage[] imgs) {
    int yPos = 0;
    for (PImage img : imgs) {
        if (img != null) {
            image(img, 0, yPos);
            yPos += img.height;
        }
    }
}

void displayAnalysis() {
    // Exibe resultados das análises como gráficos e estatísticas
    int totalElements = processor.countElements(images);
    textSize(16);
    fill(255);
    text("Total elements identified: " + totalElements, 10, 30);
}

class ImageProcessor {
    TratarImagens tratarImagens = new TratarImagens();
    ExecutorService executor = Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors()); // Utiliza todos os processadores disponíveis

    void processImages(PImage[] imgs) {
        for (PImage img : imgs) {
            executor.submit(() -> processImage(img));
        }
        executor.shutdown();
        try {
            executor.awaitTermination(Long.MAX_VALUE, TimeUnit.NANOSECONDS);
        } catch (InterruptedException e) {
            println("Interrupted: " + e.getMessage());
        }
    }

    void processImage(PImage img) {
        if (img != null) {
            img.resize(300, 300);
            img = tratarImagens.filtroBrilho(img, 150);
            img = tratarImagens.aplicarFiltroMediana(img);
            img = tratarImagens.aplicarFiltroSobel(img);
            img = tratarImagens.aplicarFiltroLaplaciano(img);
            img = tratarImagens.aplicarFiltroGabor(img, 45);
            img = tratarImagens.aplicarOperacoesMorfologicas(img, 5);
        }
    }

    int countElements(PImage[] imgs) {
        int count = 0;
        for (PImage img : imgs) {
            // Primeiro, assegurar que a imagem foi processada pelos filtros adequados para simplificar a segmentação
            img.filter(THRESHOLD); // Aplica um filtro de limiar para converter a imagem em preto e branco
            
            // Iniciar a análise de componentes conectados
            int[][] labels = new int[img.width][img.height]; // Armazena os rótulos para cada componente
            int label = 1; // Inicia os rótulos de componentes
    
            for (int y = 0; y < img.height; y++) {
                for (int x = 0; x < img.width; x++) {
                    if (img.pixels[y * img.width + x] == color(255) && labels[x][y] == 0) { // Verifica se o pixel é branco e não rotulado
                        floodFill(img, labels, x, y, label);
                        label++;
                    }
                }
            }
            
            count += label - 1; // Adiciona o número de componentes encontrados nesta imagem ao total
        }
        return count;
    }
    
    void floodFill(PImage img, int[][] labels, int x, int y, int label) {
        // Uma implementação simples de flood fill usando uma pilha para evitar estouro de pilha de chamadas recursivas
        ArrayDeque<Point> stack = new ArrayDeque<>();
        stack.push(new Point(x, y));
        while (!stack.isEmpty()) {
            Point p = stack.pop();
            if (p.x < 0 || p.y < 0 || p.x >= img.width || p.y >= img.height) continue; // Verifica limites
            if (labels[p.x][p.y] > 0 || img.pixels[p.y * img.width + p.x] != color(255)) continue; // Verifica se já rotulado ou não é branco
    
            labels[p.x][p.y] = label; // Rotula o componente
    
            // Empilha todos os vizinhos ortogonais
            stack.push(new Point(p.x + 1, p.y));
            stack.push(new Point(p.x - 1, p.y));
            stack.push(new Point(p.x, p.y + 1));
            stack.push(new Point(p.x, p.y - 1));
        }
    }

}

class TratarImagens {
    PImage processarFiltros(PImage img) {
        img = filtroBrilho(img, 150);
        img = aplicarFiltroMediana(img);
        img = aplicarFiltroSobel(img);
        img = aplicarFiltroLaplaciano(img);
        img = aplicarFiltroGabor(img, 45);
        img = aplicarOperacoesMorfologicas(img, 5);
        return img;
    }

    PImage filtroBrilho(PImage img, float aumento) {
        if (img == null) return null;
        img.loadPixels();
        for (int i = 0; i < img.pixels.length; i++) {
            float r = red(img.pixels[i]) + aumento;
            float g = green(img.pixels[i]) + aumento;
            float b = blue(img.pixels[i]) + aumento;
            img.pixels[i] = color(min(r, 255), min(g, 255), min(b, 255));
        }
        img.updatePixels();
        return img;
    }

    PImage aplicarFiltroMediana(PImage img) {
        return aplicarFiltroGenerico(img, 3);  // Aplica filtro mediana com janela de 3x3
    }

    PImage aplicarFiltroSobel(PImage img) {
        if (img == null) return null;
        float[][] sx = {{-1, 0, 1}, {-2, 0, 2}, {-1, 0, 1}};
        float[][] sy = {{-1, -2, -1}, {0, 0, 0}, {1, 2, 1}};
        return aplicarFiltroConvolucao(img, sx, sy);
    }

    PImage aplicarFiltroLaplaciano(PImage img) {
        if (img == null) return null;
        float[][] kernel = {
            {0, 1, 0},
            {1, -4, 1},
            {0, 1, 0}
        };
        return aplicarFiltroConvolucao(img, kernel, kernel); 
    }

    PImage aplicarFiltroGabor(PImage img, double theta) {
        if (img == null) return null;
        int size = 5;
        float lambda = 10;
        float sigma = lambda * 0.56;
        float[][] kernel = new float[size][size];
        float thetaRad = (float) (theta * Math.PI / 180);
        float x_theta, y_theta;

        for (int x = -size / 2; x <= size / 2; x++) {
            for (int y = -size / 2; y <= size / 2; y++) {
                x_theta = (float) (x * Math.cos(thetaRad) + y * Math.sin(thetaRad));
                y_theta = (float) (-x * Math.sin(thetaRad) + y * Math.cos(thetaRad));
                kernel[x + size / 2][y + size / 2] = (float) Math.exp(-(x_theta * x_theta + y_theta * y_theta) / (2 * sigma * sigma)) * (float) Math.cos(2 * Math.PI x_theta / lambda);
            }
        }

        return aplicarFiltroConvolucao(img, kernel, kernel);
    }

    PImage aplicarOperacoesMorfologicas(PImage img, int iterations) {
        img = dilatar(img, iterations);
        img = erodir(img, iterations);
        return img;
    }

    PImage dilatar(PImage img, int iterations) {
        if (img == null) return null;
        PImage result = img.get();  // Cria uma cópia da imagem original para manipulação
        int width = img.width;
        int height = img.height;

        // Elemento estruturante (3x3 com o elemento do centro como referência)
        int[][] structuringElement = {
            {1, 1, 1},
            {1, 1, 1},
            {1, 1, 1}
        };

        // Aplicar a dilatação várias vezes de acordo com 'iterations'
        for (int iter = 0; iter < iterations; iter++) {
            result.loadPixels();
            PImage tempImg = result.get(); // Trabalhar com uma cópia durante a iteração
            tempImg.loadPixels();

            for (int y = 1; y < height - 1; y++) {
                for (int x = 1; x < width - 1; x++) {
                    // Encontrar o máximo de cada canal na vizinhança
                    float maxR = 0, maxG = 0, maxB = 0;
                    for (int i = -1; i <= 1; i++) {
                        for (int j = -1; j <= 1; j++) {
                            int pos = (y + i) * width + (x + j);
                            int pixelVal = tempImg.pixels[pos];
                            int structVal = structuringElement[i + 1][j + 1];

                            if (structVal == 1) {  // Apenas processa se o elemento estruturante permitir
                                maxR = max(maxR, red(pixelVal));
                                maxG = max(maxG, green(pixelVal));
                                maxB = max(maxB, blue(pixelVal));
                            }
                        }
                    }

                    // Definir o pixel resultante com os máximos encontrados
                    int index = y * width + x;
                    result.pixels[index] = color(maxR, maxG, maxB);
                }
            }

            result.updatePixels();
        }

        return result;
    }

    PImage erodir(PImage img, int iterations) {
        if (img == null) return null;
        PImage result = img.get();  // Cria uma cópia da imagem original para manipulação
        int width = img.width;
        int height = img.height;

        // Elemento estruturante (3x3 com o elemento do centro como referência)
        int[][] structuringElement = {
            {1, 1, 1},
            {1, 1, 1},
            {1, 1, 1}
        };

        // Aplicar a erosão várias vezes de acordo com 'iterations'
        for (int iter = 0; iter < iterations; iter++) {
            result.loadPixels();
            PImage tempImg = result.get(); // Trabalhar com uma cópia durante a iteração
            tempImg.loadPixels();

            for (int y = 1; y < height - 1; y++) {
                for (int x = 1; x < width - 1; x++) {
                    // Encontrar o mínimo de cada canal na vizinhança
                    float minR = 255, minG = 255, minB = 255;
                    for (int i = -1; i <= 1; i++) {
                        for (int j = -1; j <= 1; j++) {
                            int pos = (y + i) * width + (x + j);
                            int pixelVal = tempImg.pixels[pos];
                            int structVal = structuringElement[i + 1][j + 1];

                            if (structVal == 1) {  // Apenas processa se o elemento estruturante permitir
                                minR = min(minR, red(pixelVal));
                                minG = min(minG, green(pixelVal));
                                minB = min(minB, blue(pixelVal));
                            }
                        }
                    }

                    // Definir o pixel resultante com os mínimos encontrados
                    int index = y * width + x;
                    result.pixels[index] = color(minR, minG, minB);
                }
            }

            result.updatePixels();
        }

        return result;
    }

    // Métodos auxiliares
    PImage aplicarFiltroGenerico(PImage img, int size) {
        if (img == null) return null;
        PImage result = createImage(img.width, img.height, RGB);
        img.loadPixels();
        result.loadPixels();

        // Criar um kernel de suavização (blur) como exemplo
        float[][] kernel = createBlurKernel(size);

        int edge = size / 2; // Margem devido ao tamanho do kernel

        // Aplicar o filtro de convolução
        for (int y = edge; y < img.height - edge; y++) {
            for (int x = edge; x < img.width - edge; x++) {
                float sumR = 0, sumG = 0, sumB = 0;
                float kernelSum = 0; // Somatório dos pesos do kernel para normalização

                // Aplicar o kernel à vizinhança do pixel (x, y)
                for (int ky = -edge; ky <= edge; ky++) {
                    for (int kx = -edge; kx <= edge; kx++) {
                        int pixelIndex = (y + ky) * img.width + (x + kx);
                        float kernelVal = kernel[ky + edge][kx + edge];

                        sumR += red(img.pixels[pixelIndex]) * kernelVal;
                        sumG += green(img.pixels[pixelIndex]) * kernelVal;
                        sumB += blue(img.pixels[pixelIndex]) * kernelVal;
                        kernelSum += kernelVal;
                    }
                }

                // Normalizar e definir o pixel no resultado
                int index = y * img.width + x;
                result.pixels[index] = color(sumR / kernelSum, sumG / kernelSum, sumB / kernelSum);
            }
        }

        result.updatePixels();
        return result;
    }

    // Função para criar um kernel de suavização (blur) simétrico
    float[][] createBlurKernel(int size) {
        float[][] kernel = new float[size][size];
        float weight = 1.0 / (size * size);  // Peso igual para um kernel de média simples
        for (int i = 0; i < size; i++) {
            for (int j = 0; j < size; j++) {
                kernel[i][j] = weight;
            }
        }
        return kernel;
    }

    PImage aplicarFiltroConvolucao(PImage img, float[][] sx, float[][] sy) {
        if (img == null) return null;
        PImage result = createImage(img.width, img.height, RGB);
        img.loadPixels();
        result.loadPixels();

        int width = img.width;
        int height = img.height;
        int kernelSize = sx.length;  // Assume que os kernels sx e sy são quadrados e do mesmo tamanho
        int edge = kernelSize / 2;  // Margem devido ao tamanho do kernel

        for (int y = edge; y < height - edge; y++) {
            for (int x = edge; x < width - edge; x++) {
                float sumRx = 0, sumGx = 0, sumBx = 0;
                float sumRy = 0, sumGy = 0, sumBy = 0;

                // Aplicar os kernels sx e sy à vizinhança do pixel (x, y)
                for (int ky = -edge; ky <= edge; ky++) {
                    for (int kx = -edge; kx <= edge; kx++) {
                        int pixelIndex = (y + ky) * width + (x + kx);
                        int pixelColor = img.pixels[pixelIndex];

                        float kxVal = sx[ky + edge][kx + edge];
                        float kyVal = sy[ky + edge][kx + edge];

                        sumRx += red(pixelColor) * kxVal;
                        sumGx += green(pixelColor) * kxVal;
                        sumBx += blue(pixelColor) * kxVal;

                        sumRy += red(pixelColor) * kyVal;
                        sumGy += green(pixelColor) * kyVal;
                        sumBy += blue(pixelColor) * kyVal;
                    }
                }

                // Calcula a magnitude do gradiente para cada canal
                float r = sqrt(sumRx * sumRx + sumRy * sumRy);
                float g = sqrt(sumGx * sumGx + sumGy * sumGy);
                float b = sqrt(sumBx * sumBx + sumBy * sumBy);

                // Limita os valores a 255
                r = constrain(r, 0, 255);
                g = constrain(g, 0, 255);
                b = constrain(b, 0, 255);

                // Definir o pixel resultante
                result.pixels[y * width + x] = color(r, g, b);
            }
        }

        result.updatePixels();
        return result;
    }
}
