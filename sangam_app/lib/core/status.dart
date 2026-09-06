import 'package:flutter/material.dart';

import 'theme.dart';

/// Status vocabulary shared by the report card, the detail timeline and the
/// dashboard, so one status never reads two different ways.
class ProblemStatus {
  static const _labels = <String, String>{
    'SUBMITTED': 'Submitted',
    'CLASSIFIED': 'Under review',
    'VALIDATED': 'Accepted',
    'ROUTED': 'Assigned',
    'PROPOSAL_SUBMITTED': 'Solution proposed',
    'FUNDED': 'Funded',
    'IN_EXECUTION': 'In progress',
    'DEPLOYED': 'Solution deployed',
    'CLOSED_WITH_IMPACT': 'Resolved',
    'REJECTED': 'Not accepted',
    'MERGED': 'Merged',
  };

  static String label(String code) => _labels[code] ?? code;

  /// (soft background, foreground) for the status chip and the card rail.
  static (Color, Color) colors(String code) {
    switch (code) {
      case 'DEPLOYED':
      case 'CLOSED_WITH_IMPACT':
        return (AppColors.successSoft, AppColors.success);
      case 'REJECTED':
        return (AppColors.dangerSoft, AppColors.danger);
      case 'IN_EXECUTION':
      case 'FUNDED':
      case 'PROPOSAL_SUBMITTED':
      case 'ROUTED':
        return (AppColors.warningSoft, AppColors.warning);
      default:
        return (AppColors.primarySoft, AppColors.primary);
    }
  }

  static bool isResolved(String code) =>
      code == 'DEPLOYED' || code == 'CLOSED_WITH_IMPACT';

  static bool isOpen(String code) =>
      !isResolved(code) && code != 'REJECTED';
}
