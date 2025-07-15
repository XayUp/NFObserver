import 'package:flutter/material.dart';
import 'package:nfobserver/features/home/provider/nf_provider.dart';
import 'package:provider/provider.dart';

class StatusFooter extends StatelessWidget {
  const StatusFooter({super.key});

  @override
  Widget build(BuildContext context) {
    // O Consumer reconstrói este widget sempre que o NFProvider notifica os ouvintes.
    return Consumer<NFProvider>(
      builder: (context, provider, child) {
        return BottomAppBar(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A barra de progresso só é visível quando 'isEnriching' é verdadeiro.
                // Usamos AnimatedOpacity para uma transição suave.
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: provider.isEnriching ? 1.0 : 0.0,
                  child: const LinearProgressIndicator(),
                ),
                if (provider.isEnriching) const SizedBox(height: 4),
                // Mensagem de status.
                Text(
                  provider.statusMessage,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
