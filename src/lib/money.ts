const peso = (fractionDigits: number) =>
  new Intl.NumberFormat('en-PH', {
    style: 'currency',
    currency: 'PHP',
    minimumFractionDigits: fractionDigits,
    maximumFractionDigits: fractionDigits,
  });

const wholePeso = peso(0);
const exactPeso = peso(2);

export function formatPeso(amount: number): string {
  return (Number.isInteger(amount) ? wholePeso : exactPeso).format(amount);
}
