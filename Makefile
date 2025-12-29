NAME = pbrain-gomoku-ai
ZIG_TARBALL = zig-x86_64-linux-0.16.0-dev.1484+d0ba6642b.tar.xz
ZIG_DIR = zig
ZIG = ./$(ZIG_DIR)/zig

all: $(NAME)

$(NAME):
	@if [ ! -d "$(ZIG_DIR)" ]; then \
		tar -xf $(ZIG_TARBALL); \
		mv zig-x86_64-linux-0.16.0-dev.1484+d0ba6642b $(ZIG_DIR); \
	fi
	@echo "Building $(NAME)..."
	@$(ZIG) build -p .
	@mv bin/G_AIA_500_TLS_5_1_gomoku_16 $(NAME)

re: fclean all

clean:
	rm -rf zig-cache/ .zig-cache/

fclean: clean
	rm -rf zig-out/ bin/ $(ZIG_DIR) $(NAME)

.PHONY: all re clean fclean
