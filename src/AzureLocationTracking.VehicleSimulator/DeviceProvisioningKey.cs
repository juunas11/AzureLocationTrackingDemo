using Microsoft.Azure.Devices.Shared;
using System.Security.Cryptography;
using System.Text;

namespace AzureLocationTracking.VehicleSimulator;
internal static class DeviceProvisioningKey
{
    public static SecurityProviderSymmetricKey CreateFromEnrollmentGroupKey(
        string enrollmentGroupPrimaryKey,
        Guid deviceId)
    {
        byte[] enrollmentKeyBytes = Convert.FromBase64String(enrollmentGroupPrimaryKey);
        using var hmac = new HMACSHA256(enrollmentKeyBytes);

        byte[] derivedKeyHash = hmac.ComputeHash(Encoding.UTF8.GetBytes(deviceId.ToString()));

        string derivedKey = Convert.ToBase64String(derivedKeyHash);

        return new SecurityProviderSymmetricKey(deviceId.ToString(), derivedKey, null);
    }
}
