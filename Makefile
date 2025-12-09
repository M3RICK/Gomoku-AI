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
	@$(ZIG) build

re: fclean all

clean:
	rm -rf zig-cache/ .zig-cache/

fclean: clean
	rm -rf zig-out/ $(ZIG_DIR)

.PHONY: all re clean fclean
