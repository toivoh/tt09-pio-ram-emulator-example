/*
 * Copyright (c) 2024 Andy Sloane and Toivo Henningsson
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdio.h>
#include <stdlib.h>

#include <SDL2/SDL.h>

#include "Vvtop.h"
#include "verilated.h"



const int FULL_WIDTH = 800;
const int FULL_HEIGHT = 525;

const int SCREEN_WIDTH = 640;
const int SCREEN_HEIGHT = 480;

const int BP_H = 48;
const int BP_V = 33;


Vvtop *top;

void timestep() { top->clk = 0; top->eval(); top->clk = 1; top->eval(); }
void timestep2() { timestep(); timestep(); }

int main(int argc, char** argv) {
	Verilated::commandArgs(argc, argv);

	top = new Vvtop();

	top->use_both_button_dirs = 1;

	top->rst_n = 0;
	timestep2();
	top->rst_n = 1;


	// Align to end of vsync
	//while (!top->vsync) { timestep(); }
	//for (int i = 0; i < BP_V*FULL_WIDTH; i++) { timestep2(); }

	// Align to end of hsync
	while (!top->hsync) { timestep(); }
	// Align to end of back porch
	for (int i = 0; i < BP_H; i++) { timestep2(); }

	// Initialize SDL
	if (SDL_Init(SDL_INIT_VIDEO) != 0) {
		SDL_Log("Failed to initialize SDL: %s", SDL_GetError());
		return 1;
	}

	// Create a window
	SDL_Window* window = SDL_CreateWindow("pio-ram-emulator example: Julia fractal", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, SCREEN_WIDTH, SCREEN_HEIGHT, 0);
	if (window == nullptr) {
		SDL_Log("Failed to create window: %s", SDL_GetError());
		SDL_Quit();
		return 1;
	}

	// Create a renderer and get a pointer to a framebuffer
	SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
	if (renderer == nullptr) {
		SDL_Log("Failed to create renderer: %s", SDL_GetError());
		SDL_DestroyWindow(window);
		SDL_Quit();
		return 1;
	}

	// Create a texture that we'll use as our framebuffer
	SDL_Texture* texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, SCREEN_WIDTH, SCREEN_HEIGHT);
	if (texture == nullptr) {
		SDL_Log("Failed to create texture: %s", SDL_GetError());
		SDL_DestroyRenderer(renderer);
		SDL_DestroyWindow(window);
		SDL_Quit();
		return 1;
	}

	// Main loop
	bool quit = false;
	int buttons = 0;
	while (!quit) {
		// Handle events
		SDL_Event event;
		while (SDL_PollEvent(&event)) {
			if (event.type == SDL_QUIT) quit = true;
			else if (event.type == SDL_KEYDOWN || event.type == SDL_KEYUP) {
				int sym = event.key.keysym.sym;
				int index = -1;
				if (sym == SDLK_MINUS || sym == SDLK_KP_MINUS) index = 5;
				else if (sym == SDLK_PLUS || sym == SDLK_KP_PLUS) index = 4;
				else if (sym == SDLK_LEFT) index = 3;
				else if (sym == SDLK_RIGHT) index = 2;
				else if (sym == SDLK_DOWN) index = 1;
				else if (sym == SDLK_UP) index = 0;

				if (index >= 0) {
					if (event.type == SDL_KEYDOWN) buttons |= (1 << index);
					else buttons &= ~(1 << index);
				}

				//printf("index = %d, down = %d\n", index, event.type == SDL_KEYDOWN);
			}
		}

		top->buttons = buttons;

		// Get a framebuffer pointer
		uint32_t* pixels;
		int pitch;
		int ret = SDL_LockTexture(texture, nullptr, (void**)&pixels, &pitch);
		if (ret != 0) {
			SDL_Log("Failed to lock texture: %s", SDL_GetError());
			break;
		}

		if (pitch != SCREEN_WIDTH*4) {
			SDL_Log("Unexpected pitch: %d", pitch);
			break;
		}

		for(int y = 0; y < FULL_HEIGHT; y++) {
			for(int x = 0; x < FULL_WIDTH; x++) {
				timestep2();

				if (y < SCREEN_HEIGHT && x < SCREEN_WIDTH) {
					//   assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
					//int rgb = top->rgb;
					int r = top->r;
					int g = top->g;
					int b = top->b;
					r *= 85; g *= 85; b *= 85;

					uint32_t color = 0xFF000000 | (r << 16) | (g << 8) | b;
					pixels[x + y*SCREEN_WIDTH] = color;
				}
			}
		}

		// Unlock the texture
		SDL_UnlockTexture(texture);

		SDL_RenderCopy(renderer, texture, nullptr, nullptr);

		// Update the screen
		SDL_RenderPresent(renderer);

		if (top->error_status != 0) printf("error_status = 0x%x\n", top->error_status);
	}

	// Cleanup
	SDL_DestroyRenderer(renderer);
	SDL_DestroyWindow(window);
	SDL_Quit();

	delete top;
	return 0;
}
