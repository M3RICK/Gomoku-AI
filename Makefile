NAME = pbrain-gomoku-ai

all: $(NAME)

$(NAME):
	zig build

re: fclean all

clean:
	rm -rf zig-cache/

fclean: clean
	rm -rf zig-out/

.PHONY: all re clean fclean
